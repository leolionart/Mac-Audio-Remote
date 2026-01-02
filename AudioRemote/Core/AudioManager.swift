import Foundation
import CoreAudio
import Combine

class AudioManager: ObservableObject {
    // Input (Microphone) properties
    @Published var isMuted: Bool = false
    @Published var currentVolume: Float32 = 0.0

    // Output (Speaker) properties
    @Published var outputVolume: Float32 = 0.5
    @Published var isOutputMuted: Bool = false

    private var inputDeviceID: AudioDeviceID = 0
    private var outputDeviceID: AudioDeviceID = 0
    private var inputListenerAdded: Bool = false
    private var outputListenerAdded: Bool = false

    init() {
        setupAudioDevices()
        updateCurrentState()
        updateOutputState()
        observeVolumeChanges()
        observeOutputVolumeChanges()
    }

    deinit {
        removeVolumeObserver()
        removeOutputVolumeObserver()
    }

    // MARK: - Public Methods

    /// Toggle microphone mute state
    /// - Returns: true if muted, false if unmuted
    @discardableResult
    func toggle() -> Bool {
        let volume = getVolume()
        let newVolume: Float32 = (volume == 0.0) ? 1.0 : 0.0
        setVolume(newVolume)
        updateCurrentState()
        return isMuted
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
        outputVolume = volume
        isOutputMuted = (volume == 0.0)
    }

    private func updateCurrentState() {
        let volume = getVolume()
        currentVolume = volume
        isMuted = (volume == 0.0)
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
}
