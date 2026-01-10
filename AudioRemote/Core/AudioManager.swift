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

    // Output (Speaker) properties
    @Published var outputVolume: Float32 = 0.5
    @Published var isOutputMuted: Bool = false

    // Device switching properties
    @Published var availableInputDevices: [AudioInputDevice] = []
    var muteMode: MuteMode = .hardwareMute
    var nullDeviceUID: String?
    var realMicDeviceUID: String?
    var forceChannelMute: Bool = true

    // Store original volumes for null device channels to restore on unmute
    private var nullDeviceOriginalVolumes: [UInt32: Float32] = [:]

    // Default input/output device IDs
    // Internal(set) so HTTP layer can inspect current device for silence injection
    internal private(set) var inputDeviceID: AudioDeviceID = 0
    internal private(set) var outputDeviceID: AudioDeviceID = 0
    private var inputListenerAdded: Bool = false
    private var outputListenerAdded: Bool = false
    private var defaultInputListenerAdded: Bool = false

    // Silence injection for virtual devices (e.g., BlackHole)
    private var silenceEngine: AVAudioEngine?
    private var silencePlayer: AVAudioPlayerNode?

    // Active monitoring for bypass detection
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 0.1 // 100ms
    private var consecutiveLeakDetections: Int = 0
    private let maxLeakDetections: Int = 3

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
        stopSilenceInjection()
        removeVolumeObserver()
        removeOutputVolumeObserver()
        removeDefaultInputDeviceObserver()
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
            // Unmute: stop monitoring, restore real microphone, stop silence injection, restore volumes
            stopActiveMonitoring()
            stopSilenceInjection()

            // Restore original volumes if we forced mute on the null device
            if let nullUID = nullDeviceUID,
               let nullDeviceID = findDeviceByUID(nullUID) {
                restoreNullDeviceVolumes(deviceID: nullDeviceID)
            }

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
            // Mute: save current mic, switch to null device, inject silence if virtual
            saveCurrentMicAsReal()

            guard let nullUID = nullDeviceUID,
                  let nullDeviceID = findDeviceByUID(nullUID) else {
                print("Null device not configured, fallingback to volume mode")
                return toggleViaVolume()
            }

            // Force mute channels on null device BEFORE switching if possible, or immediately after
            if forceChannelMute {
                muteAllChannelsOnDevice(deviceID: nullDeviceID)
            }

            if setDefaultInputDevice(nullDeviceID) {
                startSilenceInjectionIfNeeded(deviceID: nullDeviceID)
                DispatchQueue.main.async { [weak self] in
                    self?.isMuted = true
                }
                print("Muted: switched to \(getDeviceName(nullDeviceID) ?? "null device")")

                // Check for signal leak after short delay
                checkSignalLeak(deviceID: nullDeviceID)

                // NEW: Start active monitoring to detect bypass attempts
                startActiveMonitoring()

                return true
            }
        }
        return isMuted
    }

    /// Save current microphone as the real mic for later restore
    func saveCurrentMicAsReal() {
        if let uid = getDeviceUID(inputDeviceID) {
            // Safety check: Don't save null device as real mic
            if let nullUID = nullDeviceUID, uid == nullUID {
                print("Warning: Current device is null device, ignoring save request")
                return
            }
            // Safety check: Don't save if device name contains "BlackHole" or "Null" if nullDeviceUID is not set yet
            if let name = getDeviceName(inputDeviceID),
               name.lowercased().contains("blackhole") || name.lowercased().contains("null") {
                print("Warning: Detected virtual device '\(name)', ignoring save request")
                return
            }

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

    // MARK: - Channel Mute & Leak Detection

    /// Mute all channels on a specific device and save original volumes
    private func muteAllChannelsOnDevice(deviceID: AudioDeviceID) {
        // Clear previous saved volumes
        nullDeviceOriginalVolumes.removeAll()

        // Get number of channels
        _ = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Iterate over channels (simplification: assume 1-2 streams, check stereo)
        // Better: iterate channels. For now, try Main, 1, 2.
        let channels: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]

        for channel in channels {
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )

            if AudioObjectHasProperty(deviceID, &volAddress) {
                var volume: Float32 = 0.0
                var size = UInt32(MemoryLayout<Float32>.size)

                // Get current volume
                if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &size, &volume) == noErr {
                    nullDeviceOriginalVolumes[channel] = volume
                }

                // Set to 0
                var zero: Float32 = 0.0
                let setStatus = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, size, &zero)

                if setStatus != noErr {
                    print("Failed to zero volume for channel \(channel) on device \(deviceID) (Error: \(setStatus))")
                } else {
                    // Verify
                    var checkVol: Float32 = -1.0
                    AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &size, &checkVol)
                    print("Channel \(channel) volume on device \(deviceID) -> Set: 0.0, Actual: \(checkVol)")
                }
            }

            // Try to set MUTE property as well (Stronger than volume 0)
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )

            if AudioObjectHasProperty(deviceID, &muteAddress) {
                var muted: UInt32 = 1
                let size = UInt32(MemoryLayout<UInt32>.size)
                if AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, size, &muted) == noErr {
                    print("Hard Muted (Property) channel \(channel) on device \(deviceID)")
                } else {
                    print("Failed to Hard Mute channel \(channel)")
                }
            }
        }
    }

    /// Restore original volumes for null device
    private func restoreNullDeviceVolumes(deviceID: AudioDeviceID) {
        for (channel, volume) in nullDeviceOriginalVolumes {
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )
            var vol = volume
            let size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, size, &vol) == noErr {
                print("Restored volume \(volume) for channel \(channel)")
            }

            // Restore Mute property (Unmute)
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )
            if AudioObjectHasProperty(deviceID, &muteAddress) {
                var unmuted: UInt32 = 0
                let muteSize = UInt32(MemoryLayout<UInt32>.size)
                AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, muteSize, &unmuted)
            }
        }
        nullDeviceOriginalVolumes.removeAll()
    }

    /// Check for signal leak on null device
    private func checkSignalLeak(deviceID: AudioDeviceID) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isMuted, self.inputDeviceID == deviceID else { return }

            // Create temporary engine to tap and measure RMS
            let engine = AVAudioEngine()
            let input = engine.inputNode // This will use the current system default input (which is deviceID)
            let format = input.outputFormat(forBus: 0)

            var maxRMS: Float = 0.0
            let semaphore = DispatchSemaphore(value: 0)

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                guard let data = buffer.floatChannelData?[0] else { return }
                var sum: Float = 0
                for i in 0..<Int(buffer.frameLength) {
                    sum += data[i] * data[i]
                }
                let rms = sqrt(sum / Float(buffer.frameLength))
                if rms > maxRMS { maxRMS = rms }
            }

            do {
                try engine.start()
                // Measure for 200ms
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    engine.stop()
                    engine.inputNode.removeTap(onBus: 0)
                    semaphore.signal()
                }
                semaphore.wait()

                // Threshold: -60dB is roughly 0.001. If > 0.001, potential leak.
                if maxRMS > 0.001 {
                    print("⚠️ WARNING: Signal leak detected on null device! RMS: \(maxRMS). Check routing (e.g. Multi-Output)")
                } else {
                    print("✅ Null device verified silent (RMS: \(maxRMS))")
                }

            } catch {
                print("Failed to check signal leak: \(error)")
            }
        }
    }

    // MARK: - Active Monitoring for Bypass Detection

    /// Start continuous monitoring when muted to detect bypass attempts
    func startActiveMonitoring() {
        guard monitoringTimer == nil else { return }

        // CRITICAL: Timer must be scheduled on main RunLoop to work properly
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Fire first check immediately
            self.verifyDeviceNotChanged()
            self.verifyChannelVolumes()

            self.monitoringTimer = Timer.scheduledTimer(withTimeInterval: self.monitoringInterval, repeats: true) { [weak self] _ in
                guard let self = self, self.isMuted else {
                    self?.stopActiveMonitoring()
                    return
                }

                // Check 1: Verify null device still active
                self.verifyDeviceNotChanged()

                // Check 2: Verify channel volumes still zero
                self.verifyChannelVolumes()

                // Check 3: Monitor for audio signal leak
                self.monitorSignalLeak()
            }

            print("✓ Active monitoring started (checking every \(Int(self.monitoringInterval * 1000))ms)")
        }
    }

    /// Stop active monitoring
    func stopActiveMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.monitoringTimer?.invalidate()
            self?.monitoringTimer = nil
            self?.consecutiveLeakDetections = 0
            print("✓ Active monitoring stopped")
        }
    }

    /// Verify device hasn't been switched away from null device
    private func verifyDeviceNotChanged() {
        guard let currentUID = getDeviceUID(inputDeviceID),
              let nullUID = nullDeviceUID else {
            print("[Monitor] Cannot verify - missing UIDs")
            return
        }

        print("[Monitor] Check: current=\(String(currentUID.prefix(20)))... vs null=\(String(nullUID.prefix(20)))...")

        if currentUID != nullUID {
            print("⚠️ Device switched detected! Forcing back to null device")
            print("[Monitor] Current: \(currentUID)")
            print("[Monitor] Expected: \(nullUID)")
            forceRestoreMuteState()
        } else {
            print("[Monitor] ✓ Device OK")
        }
    }

    /// Verify channel volumes still zero
    private func verifyChannelVolumes() {
        guard let nullUID = nullDeviceUID,
              let deviceID = findDeviceByUID(nullUID) else { return }

        let channels: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]
        var needsRemute = false

        for channel in channels {
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )

            if AudioObjectHasProperty(deviceID, &volAddress) {
                var volume: Float32 = 0.0
                var size = UInt32(MemoryLayout<Float32>.size)

                if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &size, &volume) == noErr {
                    if volume > 0.01 { // Allow tiny float error
                        print("⚠️ Channel \(channel) volume restored to \(volume)! Re-muting...")
                        needsRemute = true
                    }
                }
            }
        }

        if needsRemute {
            muteAllChannelsOnDevice(deviceID: deviceID)
        }
    }

    /// Monitor for audio signal leak (quick non-blocking check)
    private func monitorSignalLeak() {
        guard let nullUID = nullDeviceUID,
              findDeviceByUID(nullUID) != nil else { return }

        // Quick RMS check (non-blocking)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Create temporary tap to measure signal
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            var maxRMS: Float = 0.0

            input.installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in
                guard let data = buffer.floatChannelData?[0] else { return }
                var sum: Float = 0
                for i in 0..<Int(buffer.frameLength) {
                    sum += data[i] * data[i]
                }
                let rms = sqrt(sum / Float(buffer.frameLength))
                if rms > maxRMS { maxRMS = rms }
            }

            do {
                try engine.start()
                Thread.sleep(forTimeInterval: 0.05) // 50ms sample
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)

                // Threshold: -60dB ≈ 0.001 RMS
                if maxRMS > 0.001 {
                    self.consecutiveLeakDetections += 1

                    if self.consecutiveLeakDetections >= self.maxLeakDetections {
                        DispatchQueue.main.async {
                            print("🚨 SIGNAL LEAK DETECTED! RMS: \(maxRMS)")
                            self.handleSignalLeak(rms: maxRMS)
                        }
                    }
                } else {
                    self.consecutiveLeakDetections = 0
                }
            } catch {
                // Ignore tap errors during monitoring
            }
        }
    }

    /// Force restore mute state when bypass detected
    func forceRestoreMuteState() {
        guard let nullUID = nullDeviceUID,
              let nullDeviceID = findDeviceByUID(nullUID) else { return }

        print("🔧 Force restoring mute state...")

        // 1. Switch back to null device
        setDefaultInputDevice(nullDeviceID)

        // 2. Re-mute all channels
        muteAllChannelsOnDevice(deviceID: nullDeviceID)

        // 3. Restart silence injection
        stopSilenceInjection()
        startSilenceInjectionIfNeeded(deviceID: nullDeviceID)

        // 4. Update UI
        DispatchQueue.main.async { [weak self] in
            self?.isMuted = true
        }
    }

    /// Handle detected signal leak
    private func handleSignalLeak(rms: Float) {
        print("⚠️ WARNING: Audio signal leak detected (RMS: \(rms))")

        // Force re-mute
        forceRestoreMuteState()

        // Show HUD warning
        DispatchQueue.main.async {
            WarningHUDController.shared.show(
                icon: "exclamationmark.shield.fill",
                title: "Mic Bypass Detected",
                message: "Auto-remuted"
            )
        }

        // Optional: Detect Multi-Output and alert
        if detectMultiOutputDevice() {
            DispatchQueue.main.async {
                WarningHUDController.shared.show(
                    icon: "circle.hexagongrid.fill",
                    title: "Multi-Output Device",
                    message: "May bypass mute"
                )
            }
        }
    }

    /// Detect Multi-Output or Aggregate devices that might bypass mute
    func detectMultiOutputDevice() -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return false }

        // Check for Multi-Output or Aggregate devices
        for deviceID in deviceIDs {
            if let name = getDeviceName(deviceID) {
                if name.lowercased().contains("multi-output") ||
                   name.lowercased().contains("aggregate") {

                    // Check if this is active device or includes our null device
                    if isDeviceActive(deviceID) ||
                       isAggregateUsingNullDevice(deviceID) {
                        print("⚠️ Multi-Output/Aggregate device detected: \(name)")
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Check if device is currently active (has streams)
    private func isDeviceActive(_ deviceID: AudioDeviceID) -> Bool {
        // Check if device is default or has active streams
        return deviceID == inputDeviceID || deviceID == outputDeviceID
    }

    /// Check if aggregate device includes our null device
    private func isAggregateUsingNullDevice(_ deviceID: AudioDeviceID) -> Bool {
        guard nullDeviceUID != nil else { return false }

        // Get sub-devices of aggregate
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyComposition,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if property exists (confirms it's aggregate)
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var dataSize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr {
            // Aggregate device detected - assume potential bypass
            return true
        }

        return false
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

        let status = withUnsafeMutablePointer(to: &name) { namePtr in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                namePtr
            )
        }

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

        let status = withUnsafeMutablePointer(to: &uid) { uidPtr in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                uidPtr
            )
        }

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

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

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

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

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

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

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

    // MARK: - Silence Injection for Virtual Inputs (e.g., BlackHole)

    /// Start injecting silence when switching to a virtual/null device so downstream apps only receive zeroed audio.
    internal func startSilenceInjectionIfNeeded(deviceID: AudioDeviceID) {
        // If already running, do nothing
        if silenceEngine != nil { return }

        // Build an engine that continuously plays silence
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        // Use a standard stereo 48k format
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
            ?? engine.mainMixerNode.outputFormat(forBus: 0)

        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        let frameCount = AVAudioFrameCount(format.sampleRate * 0.1) // 100ms buffer
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) {
            buffer.frameLength = frameCount
            // Buffer is zero-initialized → silence
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        }

        do {
            try engine.start()
            player.play()
            silenceEngine = engine
            silencePlayer = player
            print("Silence injection started for virtual input: \(getDeviceName(deviceID) ?? "unknown")")
        } catch {
            print("Failed to start silence injection: \(error)")
            silenceEngine = nil
            silencePlayer = nil
        }
    }

    /// Stop injecting silence and tear down the engine.
    private func stopSilenceInjection() {
        silencePlayer?.stop()
        silenceEngine?.stop()
        silencePlayer = nil
        silenceEngine = nil
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
                // If we are on the null device, ensure silence is injected; otherwise stop it.
                if isMuted {
                    startSilenceInjectionIfNeeded(deviceID: newDeviceID)
                } else {
                    stopSilenceInjection()
                }
            }
        } else {
            updateCurrentState()
        }

        print("Default input device changed to: \(getDeviceName(newDeviceID) ?? "unknown")")
    }

    // MARK: - Device Enumeration

    struct AudioDeviceInfo {
        let name: String
        let uid: String
    }

    func getAvailableInputDevices() -> [AudioDeviceInfo] {
        var devices = [AudioDeviceInfo]()

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)

        guard status == noErr else { return [] }

        for deviceID in deviceIDs {
            // Check if device has input streams
            var size: UInt32 = 0
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)

            // If it has input streams, it's an input device
            if size > 0 {
                if let name = getDeviceName(deviceID),
                   let uid = getDeviceUID(deviceID) {
                    devices.append(AudioDeviceInfo(name: name, uid: uid))
                }
            }
        }

        return devices
    }
}
