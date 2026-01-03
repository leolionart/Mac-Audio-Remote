---
name: macos-development
description: >-
  macOS native app development guide for Swift/SwiftUI. Use when building menu bar apps
  (NSStatusItem, NSPopover, MenuBarExtra), implementing Core Audio for volume/microphone control,
  integrating Sparkle auto-update framework, or working with Swift Package Manager for app bundles.
  Covers dockless accessory apps, SF Symbols, global keyboard shortcuts, and property listeners.
---

# macOS Native App Development

This skill provides guidance for developing native macOS applications with Swift and SwiftUI.

## When to Use

- Building menu bar (status bar) applications
- Implementing audio device control with Core Audio
- Setting up auto-updates with Sparkle framework
- Managing Swift Package Manager projects for macOS apps
- Creating dockless accessory applications

## Core Topics

### 1. Menu Bar Apps
See `references/menubar-apps.md` for:
- NSStatusItem and NSStatusBar usage
- NSPopover for menu bar popovers
- MenuBarExtra (macOS 13+) declarative API
- Hiding dock icon with `.accessory` activation policy
- SF Symbols for dynamic menu bar icons
- Global keyboard shortcuts with NSEvent

### 2. Core Audio
See `references/core-audio.md` for:
- AudioObjectPropertyAddress structure
- Default input/output device queries
- Volume control (kAudioDevicePropertyVolumeScalar)
- Mute control (kAudioDevicePropertyMute)
- Property listeners for external changes
- Device scopes (input vs output)

### 3. Sparkle Auto-Update
See `references/sparkle.md` for:
- SPM integration
- Info.plist configuration (SUFeedURL, SUPublicEDKey)
- appcast.xml structure
- EdDSA signing workflow
- SPUStandardUpdaterController usage
- Programmatic update checks

### 4. Swift Package Manager
See `references/spm.md` for:
- Package.swift manifest structure
- Adding dependencies
- Building executables
- Resource bundles
- Creating app bundles from SPM projects

## Quick Reference

### Hide Dock Icon
```swift
NSApp.setActivationPolicy(.accessory)
```

### Create Status Item
```swift
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
```

### Get Default Audio Device
```swift
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
```

### Initialize Sparkle
```swift
let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
)
```

## Project-Specific Patterns

This project demonstrates these patterns:
- `AudioManager.swift` - Core Audio volume/mute control with property listeners
- `MenuBarController.swift` - NSStatusItem with NSPopover
- `UpdateManager.swift` - Sparkle integration
- `AppDelegate.swift` - App lifecycle and accessory policy

## Best Practices

1. **Thread Safety**: Dispatch Core Audio listener callbacks to main thread
2. **Memory Management**: Remove property listeners in `deinit`
3. **Error Handling**: Always check `OSStatus == noErr`
4. **Combine Integration**: Use `@Published` properties for reactive UI updates
