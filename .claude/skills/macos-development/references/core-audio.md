# Core Audio API for macOS

## AudioObjectPropertyAddress
```swift
struct AudioObjectPropertyAddress {
    var mSelector: AudioObjectPropertySelector // Property ID
    var mScope: AudioObjectPropertyScope       // Input/Output/Global
    var mElement: AudioObjectPropertyElement   // Channel (0 = main)
}
```

## Device Scopes
- `kAudioObjectPropertyScopeGlobal` - Device-wide properties
- `kAudioDevicePropertyScopeInput` - Microphone/input properties
- `kAudioDevicePropertyScopeOutput` - Speaker/output properties

## Common Property Selectors
- `kAudioHardwarePropertyDefaultInputDevice` - System default mic
- `kAudioHardwarePropertyDefaultOutputDevice` - System default speaker
- `kAudioDevicePropertyVolumeScalar` - Volume (Float32 0.0-1.0)
- `kAudioDevicePropertyMute` - Mute state (UInt32 0/1)
- `kAudioObjectPropertyName` - Device name (CFString)

## Get Default Input Device
```swift
func getDefaultInputDevice() -> AudioDeviceID? {
    var deviceID: AudioDeviceID = kAudioObjectUnknown
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address, 0, nil, &size, &deviceID
    )
    return status == noErr ? deviceID : nil
}
```

## Get Default Output Device
```swift
func getDefaultOutputDevice() -> AudioDeviceID? {
    var deviceID: AudioDeviceID = kAudioObjectUnknown
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address, 0, nil, &size, &deviceID
    )
    return status == noErr ? deviceID : nil
}
```

## Get Volume
```swift
func getVolume(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Float32 {
    var volume: Float32 = 0.0
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    return status == noErr ? volume : 0.0
}
```

## Set Volume
```swift
func setVolume(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, volume: Float32) {
    var newVolume = max(0.0, min(1.0, volume))
    let size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newVolume)
    if status != noErr { print("Error: \(status)") }
}
```

## Mute Control
```swift
func setMute(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, muted: Bool) {
    var mute: UInt32 = muted ? 1 : 0
    let size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )

    AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mute)
}
```

## Property Listener (Detect External Changes)
```swift
class AudioManager {
    private var deviceID: AudioDeviceID = 0
    private var listenerAdded = false

    func observeVolumeChanges() {
        guard deviceID != 0, !listenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { objectID, numAddresses, addresses, clientData in
            guard let clientData = clientData else { return noErr }
            let manager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()
            DispatchQueue.main.async { manager.updateState() }
            return noErr
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = AudioObjectAddPropertyListener(deviceID, &address, callback, selfPointer)
        listenerAdded = (status == noErr)
    }

    func removeVolumeObserver() {
        guard deviceID != 0, listenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let callback: AudioObjectPropertyListenerProc = { _, _, _, _ in noErr }
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AudioObjectRemovePropertyListener(deviceID, &address, callback, selfPointer)
        listenerAdded = false
    }

    deinit { removeVolumeObserver() }
}
```

## Best Practices
1. Always check `status == noErr` after Core Audio calls
2. Remove listeners in `deinit` to prevent memory leaks
3. Dispatch listener callbacks to main thread for UI updates
4. Use `Unmanaged` carefully for passing Swift objects to C callbacks
5. Clamp volume values to 0.0-1.0 range
6. Use correct scope: `kAudioDevicePropertyScopeInput` for mic, `kAudioDevicePropertyScopeOutput` for speakers

## Common Errors
- `-2003332927`: Invalid device ID
- `-2003332924`: Property not supported
- `-50`: Parameter error
