import Foundation
import CoreAudio
import Combine
import AVFoundation

/// Represents an audio input device
struct AudioInputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String

    static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

class AudioManager: ObservableObject {
    // Input (Microphone) properties
    @Published var isMuted: Bool = false
    @Published var currentVolume: Float32 = 0.0
    @Published var currentInputDeviceName: String = ""
    @Published var inputLevel: Float = 0.0  // Real-time audio level (0.0-1.0)

    // Output (Speaker) properties
    @Published var outputVolume: Float32 = 0.5
    @Published var isOutputMuted: Bool = false

    // Device switching properties
    @Published var availableInputDevices: [AudioInputDevice] = []
    var muteMode: MuteMode = .hardwareMute
    var nullDeviceUID: String?
    var realMicDeviceUID: String?

    private var inputDeviceID: AudioDeviceID = 0
    private var outputDeviceID: AudioDeviceID = 0
    private var inputListenerAdded: Bool = false
    private var outputListenerAdded: Bool = false
    private var defaultInputListenerAdded: Bool = false

    // Audio level monitoring
    private var audioEngine: AVAudioEngine?
    private var levelUpdateTimer: Timer?
    private var isMonitoringLevel: Bool = false

    init() {
        setupAudioDevices()
        refreshInputDevices()
        updateCurrentState()
        updateOutputState()
        observeVolumeChanges()
        observeOutputVolumeChanges()
        observeDefaultInputDeviceChanges()
    }

    deinit {
        stopInputLevelMonitoring()
        removeVolumeObserver()
        removeOutputVolumeObserver()
        removeDefaultInputDeviceObserver()
    }

    // MARK: - Audio Level Monitoring

    /// Start monitoring input audio level
    func startInputLevelMonitoring() {
        guard !isMonitoringLevel else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Install tap on input node to get audio level
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }

            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)

            guard let data = channelData, frameLength > 0 else { return }

            // Calculate RMS (Root Mean Square) for audio level
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = data[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))

            // Convert to dB and normalize to 0-1 range
            // -60 dB = 0.0, 0 dB = 1.0
            let db = 20 * log10(max(rms, 0.0001))
            let normalizedLevel = max(0, min(1, (db + 60) / 60))

            DispatchQueue.main.async {
                self.inputLevel = normalizedLevel
            }
        }

        do {
            try audioEngine.start()
            isMonitoringLevel = true
            print("Audio level monitoring started")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    /// Stop monitoring input audio level
    func stopInputLevelMonitoring() {
        guard isMonitoringLevel else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isMonitoringLevel = false

        DispatchQueue.main.async { [weak self] in
            self?.inputLevel = 0
        }
        print("Audio level monitoring stopped")
    }

    // MARK: - Public Methods

    /// Toggle microphone mute state
    /// - Returns: true if muted, false if unmuted
    @discardableResult
    func toggle() -> Bool {
        switch muteMode {
        case .volumeZero:
            return toggleViaVolume()
        case .hardwareMute:
            return toggleViaHardwareMute()
        case .deviceSwitch:
            return toggleViaDeviceSwitch()
        }
    }

    /// Toggle using hardware mute property (recommended)
    private func toggleViaHardwareMute() -> Bool {
        let currentlyMuted = getHardwareMuteState()
        let newMuted = !currentlyMuted

        if setHardwareMute(newMuted) {
            DispatchQueue.main.async { [weak self] in
                self?.isMuted = newMuted
            }
            print("Hardware mute: \(newMuted ? "muted" : "unmuted")")
            return newMuted
        } else {
            // Fallback to volume if hardware mute not supported
            print("Hardware mute not supported, falling back to volume mode")
            return toggleViaVolume()
        }
    }

    /// Get hardware mute state
    func getHardwareMuteState() -> Bool {
        guard inputDeviceID != 0 else { return false }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if property is supported
        guard AudioObjectHasProperty(inputDeviceID, &address) else {
            return false
        }

        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            inputDeviceID,
            &address,
            0,
            nil,
            &size,
            &muted
        )

        return status == noErr && muted == 1
    }

    /// Set hardware mute state
    @discardableResult
    func setHardwareMute(_ mute: Bool) -> Bool {
        guard inputDeviceID != 0 else { return false }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if property is supported and settable
        guard AudioObjectHasProperty(inputDeviceID, &address) else {
            print("Hardware mute property not available for this device")
            return false
        }

        var settable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(inputDeviceID, &address, &settable)
        guard settableStatus == noErr && settable.boolValue else {
            print("Hardware mute property is not settable for this device")
            return false
        }

        var muteValue: UInt32 = mute ? 1 : 0

        let status = AudioObjectSetPropertyData(
            inputDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &muteValue
        )

        if status != noErr {
            print("Error setting hardware mute: \(status)")
            return false
        }

        return true
    }

    /// Toggle using volume (original behavior)
    private func toggleViaVolume() -> Bool {
        let volume = getVolume()
        let newVolume: Float32 = (volume == 0.0) ? 1.0 : 0.0
        setVolume(newVolume)
        updateCurrentState()
        return (newVolume == 0.0)
    }

    /// Toggle by switching input device
    private func toggleViaDeviceSwitch() -> Bool {
        if isMuted {
            // Unmute: restore real microphone
            guard let realUID = realMicDeviceUID,
                  let realDeviceID = findDeviceByUID(realUID) else {
                print("Cannot restore: real mic not found, falling back to volume mode")
                return toggleViaVolume()
            }
            if setDefaultInputDevice(realDeviceID) {
                DispatchQueue.main.async { [weak self] in
                    self?.isMuted = false
                }
                print("Unmuted: restored to \(getDeviceName(realDeviceID) ?? "unknown")")
                return false
            }
        } else {
            // Mute: save current mic, switch to null device
            saveCurrentMicAsReal()

            guard let nullUID = nullDeviceUID,
                  let nullDeviceID = findDeviceByUID(nullUID) else {
                print("Null device not configured, falling back to volume mode")
                return toggleViaVolume()
            }

            if setDefaultInputDevice(nullDeviceID) {
                DispatchQueue.main.async { [weak self] in
                    self?.isMuted = true
                }
                print("Muted: switched to \(getDeviceName(nullDeviceID) ?? "null device")")
                return true
            }
        }
        return isMuted
    }

    /// Save current microphone as the real mic for later restore
    func saveCurrentMicAsReal() {
        if let uid = getDeviceUID(inputDeviceID) {
            realMicDeviceUID = uid
            print("Saved real mic UID: \(uid)")
        }
    }

    /// Get current microphone volume (0.0 = muted, 1.0 = full)
    func getVolume() -> Float32 {
        guard inputDeviceID != 0 else { return 0.0 }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            inputDeviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )

        if status != noErr {
            print("Error getting microphone volume: \(status)")
            return 0.0
        }

        return volume
    }

    /// Set microphone volume (0.0 = muted, 1.0 = full)
    func setVolume(_ volume: Float32) {
        guard inputDeviceID != 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var newVolume = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(
            inputDeviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )

        if status != noErr {
            print("Error setting microphone volume: \(status)")
        }
    }

    // MARK: - Output Volume Control

    /// Get current output volume (0.0 = muted, 1.0 = full)
    func getOutputVolume() -> Float32 {
        guard outputDeviceID != 0 else { return 0.0 }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            outputDeviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )

        if status != noErr {
            print("Error getting output volume: \(status)")
            return 0.0
        }

        return volume
    }

    /// Set output volume (0.0 = muted, 1.0 = full)
    func setOutputVolume(_ volume: Float32) {
        guard outputDeviceID != 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var newVolume = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(
            outputDeviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )

        if status != noErr {
            print("Error setting output volume: \(status)")
        } else {
            updateOutputState()
        }
    }

    /// Increase output volume by specified amount (default 0.1)
    func increaseOutputVolume(_ amount: Float32 = 0.1) {
        let current = getOutputVolume()
        setOutputVolume(current + amount)
    }

    /// Decrease output volume by specified amount (default 0.1)
    func decreaseOutputVolume(_ amount: Float32 = 0.1) {
        let current = getOutputVolume()
        setOutputVolume(current - amount)
    }

    /// Toggle output mute state
    @discardableResult
    func toggleOutputMute() -> Bool {
        let current = getOutputVolume()
        if current > 0.0 {
            setOutputVolume(0.0)
        } else {
            setOutputVolume(0.5) // Default to 50% when unmuting
        }
        updateOutputState()
        return isOutputMuted
    }

    // MARK: - Device Enumeration

    /// Refresh the list of available input devices
    func refreshInputDevices() {
        let devices = getAllInputDevices()
        DispatchQueue.main.async { [weak self] in
            self?.availableInputDevices = devices
        }
    }

    /// Get all available audio input devices
    func getAllInputDevices() -> [AudioInputDevice] {
        var devices: [AudioInputDevice] = []

        // Get all audio devices
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            print("Error getting devices size: \(status)")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            print("Error getting devices: \(status)")
            return devices
        }

        // Filter for input devices
        for deviceID in deviceIDs {
            if hasInputCapability(deviceID),
               let name = getDeviceName(deviceID),
               let uid = getDeviceUID(deviceID) {
                devices.append(AudioInputDevice(id: deviceID, name: name, uid: uid))
            }
        }

        return devices
    }

    /// Check if a device has input capability
    func hasInputCapability(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        )

        return status == noErr && dataSize > 0
    }

    /// Get device name
    func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &name
        )

        if status == noErr, let name = name {
            return name as String
        }
        return nil
    }

    /// Get device UID (persistent identifier)
    func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &uid
        )

        if status == noErr, let uid = uid {
            return uid as String
        }
        return nil
    }

    /// Find device by UID
    func findDeviceByUID(_ uid: String) -> AudioDeviceID? {
        let devices = getAllInputDevices()
        return devices.first { $0.uid == uid }?.id
    }

    // MARK: - Device Switching

    /// Set system default input device
    @discardableResult
    func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var newDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &newDeviceID
        )

        if status == noErr {
            inputDeviceID = deviceID
            updateInputDeviceName()
            return true
        } else {
            print("Error setting default input device: \(status)")
            return false
        }
    }

    /// Update current input device name
    private func updateInputDeviceName() {
        if let name = getDeviceName(inputDeviceID) {
            DispatchQueue.main.async { [weak self] in
                self?.currentInputDeviceName = name
            }
        }
    }

    // MARK: - Private Methods

    private func setupAudioDevices() {
        // Setup input device (microphone)
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &inputAddress,
            0,
            nil,
            &deviceIDSize,
            &inputDeviceID
        )

        if status != noErr {
            print("Error getting default input device: \(status)")
        } else {
            print("Default input device ID: \(inputDeviceID)")
            updateInputDeviceName()
        }

        // Setup output device (speaker)
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            0,
            nil,
            &deviceIDSize,
            &outputDeviceID
        )

        if status != noErr {
            print("Error getting default output device: \(status)")
        } else {
            print("Default output device ID: \(outputDeviceID)")
        }
    }

    private func updateOutputState() {
        let volume = getOutputVolume()
        // @Published properties must be updated on main thread
        DispatchQueue.main.async { [weak self] in
            self?.outputVolume = volume
            self?.isOutputMuted = (volume == 0.0)
        }
    }

    private func updateCurrentState() {
        let volume = getVolume()
        // For hardware mute mode, check the actual mute state
        let muted: Bool
        if muteMode == .hardwareMute {
            muted = getHardwareMuteState()
        } else {
            muted = (volume == 0.0)
        }
        // @Published properties must be updated on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentVolume = volume
            self?.isMuted = muted
        }
    }

    private func observeVolumeChanges() {
        guard inputDeviceID != 0, !inputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { inObjectID, inNumberAddresses, inAddresses, inClientData in
            guard let clientData = inClientData else { return noErr }

            let manager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()

            DispatchQueue.main.async {
                manager.updateCurrentState()
            }

            return noErr
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = AudioObjectAddPropertyListener(
            inputDeviceID,
            &address,
            callback,
            selfPointer
        )

        if status == noErr {
            inputListenerAdded = true
        } else {
            print("Error adding input volume listener: \(status)")
        }
    }

    private func removeVolumeObserver() {
        guard inputDeviceID != 0, inputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { _, _, _, _ in noErr }
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        AudioObjectRemovePropertyListener(
            inputDeviceID,
            &address,
            callback,
            selfPointer
        )

        inputListenerAdded = false
    }

    private func observeOutputVolumeChanges() {
        guard outputDeviceID != 0, !outputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { inObjectID, inNumberAddresses, inAddresses, inClientData in
            guard let clientData = inClientData else { return noErr }

            let manager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()

            DispatchQueue.main.async {
                manager.updateOutputState()
            }

            return noErr
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = AudioObjectAddPropertyListener(
            outputDeviceID,
            &address,
            callback,
            selfPointer
        )

        if status == noErr {
            outputListenerAdded = true
        } else {
            print("Error adding output volume listener: \(status)")
        }
    }

    private func removeOutputVolumeObserver() {
        guard outputDeviceID != 0, outputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { _, _, _, _ in noErr }
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        AudioObjectRemovePropertyListener(
            outputDeviceID,
            &address,
            callback,
            selfPointer
        )

        outputListenerAdded = false
    }

    // MARK: - Default Input Device Observer

    private func observeDefaultInputDeviceChanges() {
        guard !defaultInputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { inObjectID, inNumberAddresses, inAddresses, inClientData in
            guard let clientData = inClientData else { return noErr }

            let manager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()

            DispatchQueue.main.async {
                manager.handleDefaultInputDeviceChanged()
            }

            return noErr
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            callback,
            selfPointer
        )

        if status == noErr {
            defaultInputListenerAdded = true
            print("Default input device listener added")
        } else {
            print("Error adding default input device listener: \(status)")
        }
    }

    private func removeDefaultInputDeviceObserver() {
        guard defaultInputListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { _, _, _, _ in noErr }
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            callback,
            selfPointer
        )

        defaultInputListenerAdded = false
    }

    /// Handle when default input device changes (from system or other apps)
    private func handleDefaultInputDeviceChanged() {
        // Get new default input device
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var newDeviceID: AudioDeviceID = 0
        var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &inputAddress,
            0,
            nil,
            &deviceIDSize,
            &newDeviceID
        )

        guard status == noErr else { return }

        inputDeviceID = newDeviceID
        updateInputDeviceName()

        // Update mute state based on current device
        if muteMode == .deviceSwitch {
            if let nullUID = nullDeviceUID, let currentUID = getDeviceUID(newDeviceID) {
                isMuted = (currentUID == nullUID)
            }
        } else {
            updateCurrentState()
        }

        print("Default input device changed to: \(getDeviceName(newDeviceID) ?? "unknown")")
    }
}
