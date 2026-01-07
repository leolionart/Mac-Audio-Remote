# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Audio Remote is a native macOS menu bar app for controlling both microphone (input) and speaker (output) audio with iOS Shortcuts support. This is a Swift rewrite of a previous Python implementation, achieving 50x faster toggle latency (~1ms vs ~50ms).

**Key Technologies:**
- Swift 5.9+ with SwiftUI for UI
- Core Audio API for direct audio device control (input & output)
- Vapor framework for HTTP server
- Custom GitHub Releases integration for auto-updates
- Combine for reactive state management

## Build & Run Commands

```bash
# Development build
swift build
.build/debug/AudioRemote

# Release build
swift build -c release
.build/release/AudioRemote

# Build app bundle
./scripts/build_app_bundle.sh

# Open in Xcode
open Package.swift
```

## Testing HTTP Server

```bash
# Microphone control
curl -X POST http://localhost:8765/toggle-mic
curl http://localhost:8765/status

# Volume control
curl -X POST http://localhost:8765/volume/increase
curl -X POST http://localhost:8765/volume/decrease
curl -X POST http://localhost:8765/volume/toggle-mute

# Set specific volume (0.0-1.0)
curl -X POST http://localhost:8765/volume/set -H "Content-Type: application/json" -d '{"volume": 0.5}'

# Web UI
open http://localhost:8765
```

## Release Process

**Use the `/release` skill** for releasing new versions:
```bash
# Example: Release version 2.6.0
/release 2.6.0
```

The skill handles the complete workflow:
1. Commit changes
2. Bump version in Info.plist
3. Build app bundle
4. Create and sign ZIP
5. Push, tag, and create GitHub Release

**IMPORTANT**: All builds happen locally. GitHub Actions release workflow is disabled to avoid signature mismatches.

For manual steps, see `.claude/skills/release/SKILL.md` or `docs/RELEASE_GUIDE.md`.

## Architecture

### Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| AudioManager | `Core/AudioManager.swift` | Core Audio API for volume/mute control with property listeners |
| HTTPServer | `Core/HTTPServer.swift` | Vapor-based async HTTP server with REST endpoints |
| SettingsManager | `Core/SettingsManager.swift` | UserDefaults persistence, legacy migration |
| UpdateManager | `Core/UpdateManager.swift` | Custom GitHub Releases update integration |
| MenuBarController | `UI/MenuBarController.swift` | NSStatusItem, NSPopover, icon updates |
| GlobalHotkeyManager | `Core/GlobalHotkeyManager.swift` | System-wide keyboard shortcuts |
| AppDelegate | `App/AppDelegate.swift` | App lifecycle, manager initialization |

### App Initialization Flow

1. `AudioRemoteApp` → `AppDelegate.applicationDidFinishLaunching`
2. `NSApp.setActivationPolicy(.accessory)` (hide dock icon)
3. Initialize managers: AudioManager → SettingsManager → UpdateManager → MenuBarController → HTTPServer
4. Start HTTP server if enabled in settings
5. Set up Combine publishers for reactive updates

### State Management

- All managers are `ObservableObject` with `@Published` properties
- UI binds directly to published properties via Combine
- `AudioManager.isMuted` drives menu bar icon updates
- Weak references in closures prevent retain cycles

### Core Audio Integration

- Default devices queried via `kAudioHardwarePropertyDefaultInputDevice` / `kAudioHardwarePropertyDefaultOutputDevice`
- Volume control via `kAudioDevicePropertyVolumeScalar` (Float32 0.0-1.0)
- Scope matters: `kAudioDevicePropertyScopeInput` for mic, `kAudioDevicePropertyScopeOutput` for speakers
- Property listeners detect external changes (System Settings, other apps)
- Listeners use `Unmanaged` to pass Swift object to C callbacks - must remove in `deinit`

### HTTP Server Routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/toggle-mic` | Toggle microphone mute |
| GET | `/status` | Get mic status |
| POST | `/volume/increase` | Increase speaker volume |
| POST | `/volume/decrease` | Decrease speaker volume |
| POST | `/volume/set` | Set volume (JSON: `{"volume": 0.5}`) |
| POST | `/volume/percent/:value` | Set volume by path (0.0-1.0) |
| POST | `/volume/toggle-mute` | Toggle speaker mute |
| GET | `/volume/status` | Get volume status |
| GET | `/` | Web UI |

## Key Files

- `Package.swift` - SPM manifest (Vapor dependency)

## Scripts

All build and release scripts are in `scripts/`:

| Script | Description |
|--------|-------------|
| `scripts/build_app_bundle.sh` | Creates .app bundle from SPM build |
| `scripts/release.sh` | Automated release pipeline |
| `scripts/test_local.sh` | Local testing utilities |

## Documentation

All detailed documentation is in `docs/`:

| File | Description |
|------|-------------|
| `docs/RELEASE_GUIDE.md` | Step-by-step release instructions for AI agents |
| `docs/RELEASE_PROCESS.md` | Release workflow and versioning |
| `docs/UPDATE_GUIDE.md` | Sparkle auto-update troubleshooting |
| `docs/iOS-SHORTCUTS-GUIDE.md` | iOS Shortcuts setup guide (Vietnamese) |

## Dependencies

- **Vapor 4.89.0+**: Async HTTP server with NIO

## macOS Requirements

- **Minimum**: macOS 13.0 (Ventura)
- **Permissions**: Microphone access, Accessibility (for global hotkeys)
- **Unsigned app**: Run `xattr -cr /path/to/AudioRemote.app`
