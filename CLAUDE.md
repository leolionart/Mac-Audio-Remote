# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Audio Remote is a native macOS menu bar app for controlling both microphone (input) and speaker (output) audio with iOS Shortcuts support. This is a Swift rewrite of a previous Python microphone-only implementation, achieving 50x faster toggle latency (~1ms vs ~50ms) and 80% memory reduction.

**Key Technologies:**
- Swift 5.9+ with SwiftUI for UI
- Core Audio API for direct audio device control (input & output)
- Vapor framework for HTTP server
- Combine for reactive state management
- SMAppService for login item management (macOS 13+)

## Build & Run Commands

### Development Build
```bash
swift build
.build/debug/AudioRemote
```

### Release Build
```bash
swift build -c release
.build/release/AudioRemote
```

### Build with Xcode
```bash
open Package.swift
# Then press ⌘R to build and run
```

## Automated Build & Release Pipeline

**IMPORTANT**: This project uses a fully automated local release script that handles version management, building, testing, and publishing to GitHub with Sparkle auto-update support.

### Release Script: `release.sh`

The project includes a comprehensive automated release script that handles the entire release process:

```bash
./release.sh
```

**What it does:**
1. ✅ Pre-flight checks (gh CLI, git status, uncommitted changes)
2. ✅ Version management (prompts for new version, validates semantic versioning)
3. ✅ Auto-increments build number
4. ✅ Collects release notes interactively
5. ✅ Updates Info.plist with new version
6. ✅ Builds app bundle with `build_app_bundle.sh`
7. ✅ Tests app bundle (verifies all required files)
8. ✅ Creates ZIP archive
9. ✅ Updates appcast.xml with file size and release notes
10. ✅ Git commit, tag, and push
11. ✅ Creates GitHub Release with ZIP attachment
12. ✅ Provides verification URLs

**For AI Agents**: See `RELEASE_GUIDE.md` for detailed step-by-step instructions.

### Quick Release

```bash
./release.sh
```

Follow the prompts:
- Enter new version (e.g., `2.2.0`)
- Enter release notes (one per line, empty line to finish)
- Script handles everything else automatically

### Build Script: `build_app_bundle.sh`

Builds a complete app bundle with all resources:

```bash
./build_app_bundle.sh
```

**Creates:**
- `.build/release/AudioRemote.app` - Complete app bundle
- Binary in `Contents/MacOS/`
- Info.plist, AppIcon.icns in `Contents/Resources/`
- Sparkle.framework in `Contents/Frameworks/`

### GitHub Actions Workflow

**Release Workflow** (`.github/workflows/release.yml`)
- **Trigger**: Git tags matching `v*.*.*` (created by `release.sh`)
- **Purpose**: Automated CI build (backup to local release)
- **Actions**: Build, create DMG/ZIP, create GitHub Release

**Note**: The local `release.sh` script is the primary release method. GitHub Actions serves as a backup CI pipeline.

### Version Numbering Convention

Follow Semantic Versioning (SemVer):
- **Major (X.0.0)**: Breaking changes, major rewrites
- **Minor (x.X.0)**: New features, backwards compatible
- **Patch (x.x.X)**: Bug fixes, minor improvements

Examples:
- `v2.0.0`: Swift rewrite (breaking change from Python version)
- `v2.1.0`: Added output volume control (new feature)
- `v2.1.1`: Fixed HTTP server crash (bug fix)

Build numbers auto-increment with each release.

### Release Notes Guidelines

Good release notes:
- ✅ `✨ New: Feature description`
- ✅ `🔧 Fix: Bug fix description`
- ✅ `🎯 Enhanced: Improvement description`

Bad release notes:
- ❌ Technical jargon (refactored AudioManager.swift)
- ❌ Internal details (updated dependencies)
- ❌ Vague descriptions (various improvements)

### Sparkle Auto-Update

The release script automatically updates `appcast.xml` which powers Sparkle auto-updates:
- Users with existing installations receive update notifications
- Sparkle downloads ZIP from GitHub Release
- Updates install automatically with user approval

**Appcast URL**: `https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml`

### Testing Releases

After running `release.sh`:

1. **Verify GitHub Release**:
   ```bash
   # URL provided by script
   open https://github.com/leolionart/Mac-Audio-Remote/releases/tag/vX.X.X
   ```

2. **Test Download and Install**:
   - Download ZIP from GitHub Release
   - Extract and move to Applications
   - Launch and verify functionality

3. **Test Sparkle Auto-Update**:
   - Launch previous version
   - Wait for update notification (or check manually)
   - Verify update downloads and installs correctly

### Emergency Rollback

If a release has critical issues:

```bash
# Delete GitHub release
gh release delete vX.X.X --yes

# Remove git tag
git tag -d vX.X.X
git push origin :refs/tags/vX.X.X

# Revert appcast.xml
git revert HEAD
git push origin main
```

This prevents new downloads and stops auto-updates.

### Testing HTTP Server
```bash
# Microphone control
curl -X POST http://localhost:8765/toggle-mic
curl http://localhost:8765/status

# Volume control
curl -X POST http://localhost:8765/volume/increase
curl -X POST http://localhost:8765/volume/decrease
curl -X POST http://localhost:8765/volume/toggle-mute
curl http://localhost:8765/volume/status

# Set specific volume
curl -X POST http://localhost:8765/volume/set \
  -H "Content-Type: application/json" \
  -d '{"volume": 0.5}'

# Open web UI
open http://localhost:8765
```

## Architecture

### Core Components

**AudioManager** (`AudioRemote/Core/AudioManager.swift`)
- Direct Core Audio API integration using `AudioObjectPropertyAddress`
- Controls both input (microphone) and output (speaker) devices
- Input device via `kAudioHardwarePropertyDefaultInputDevice` with scope `kAudioDevicePropertyScopeInput`
- Output device via `kAudioHardwarePropertyDefaultOutputDevice` with scope `kAudioDevicePropertyScopeOutput`
- Event-driven volume change detection using `AudioObjectPropertyListenerProc` for both devices
- Published properties for reactivity: `isMuted`, `currentVolume` (input), `outputVolume`, `isOutputMuted`
- Volume is scalar 0.0-1.0 (0.0 = muted, 1.0 = full volume)
- Methods: `toggle()`, `getVolume()`, `setVolume()`, `getOutputVolume()`, `setOutputVolume()`, `increaseOutputVolume()`, `decreaseOutputVolume()`, `toggleOutputMute()`

**HTTPServer** (`AudioRemote/Core/HTTPServer.swift`)
- Vapor-based async HTTP server
- Microphone routes: `POST /toggle-mic`, `GET /status`
- Volume routes: `POST /volume/increase`, `POST /volume/decrease`, `POST /volume/set`, `POST /volume/toggle-mute`, `GET /volume/status`
- Web UI: `GET /` (interactive HTML interface)
- Runs on background Task (Swift concurrency)
- Port availability check before starting
- CORS middleware for web access
- Weak references to managers to prevent retain cycles
- Response models: `ToggleResponse`, `StatusResponse`, `VolumeResponse`

**SettingsManager** (`AudioRemote/Core/SettingsManager.swift`)
- UserDefaults-based persistence (key: `app.settings.v2`)
- Auto-migrates from legacy Python app settings (`~/.config/mic-toggle-server/settings.json`)
- ObservableObject for SwiftUI binding
- Settings: autoStart, notificationsEnabled, httpServerEnabled, httpPort, requestCount

**AppDelegate** (`AudioRemote/App/AppDelegate.swift`)
- App lifecycle coordinator
- Initializes all managers in proper order
- Sets activation policy to `.accessory` (menu bar only, no dock icon)
- Observes settings changes to restart/stop HTTP server
- Error handling for server startup failures

**MenuBarController** (`AudioRemote/UI/MenuBarController.swift`)
- NSStatusItem-based menu bar icon
- Updates icon based on mute state (mic vs mic.slash)
- Global keyboard shortcut (⌘M) for toggle
- Opens settings window on demand

### App Initialization Flow

1. `MicToggleApp` → `AppDelegate.applicationDidFinishLaunching`
2. Set activation policy to `.accessory` (hide dock icon)
3. Initialize `AudioManager` (sets up Core Audio listeners)
4. Initialize `SettingsManager` (loads UserDefaults, migrates legacy settings)
5. Request notification authorization
6. Initialize `MenuBarController` (creates status item)
7. Initialize `HTTPServer` (but don't start yet)
8. Start HTTP server if `httpServerEnabled == true`
9. Set up Combine publisher to observe settings changes

### State Management Pattern

- All managers are `ObservableObject` with `@Published` properties
- UI components (SwiftUI) bind directly to published properties
- Changes propagate automatically via Combine
- Weak references prevent retain cycles in closures

### HTTP Server Architecture

- Vapor runs in background Task (Swift concurrency)
- Server binds to `0.0.0.0` for network access
- Toggle endpoint increments request count and shows notification
- NetworkService provides local IP detection for webhook URLs

## Important Implementation Details

### Core Audio Integration
- Default input and output devices are queried once at startup via `kAudioHardwarePropertyDefaultInputDevice` and `kAudioHardwarePropertyDefaultOutputDevice`
- Volume changes from external sources (System Settings, other apps) are detected via property listeners for both devices
- Property listeners use `Unmanaged` to safely pass Swift object reference to C callbacks
- Separate listeners for input (`inputListenerAdded`) and output (`outputListenerAdded`)
- All listeners must be removed in `deinit` to prevent memory leaks
- Output volume control uses same Core Audio API but with `kAudioDevicePropertyScopeOutput` scope

### Settings Migration
- On first launch, checks for `~/.config/mic-toggle-server/settings.json` (Python app)
- Migrates: `auto_start`, `notifications`, `remote_access`, `request_count`
- Sets `migrated_from_python` flag in UserDefaults to prevent re-migration
- Migration happens automatically before first `save()` call

### Menu Bar Status Item
- Icon updates are driven by `AudioManager.isMuted` published property
- SF Symbols used: `mic` (unmuted) and `mic.slash` (muted)
- Menu rebuilds on each click to show current state

### Error Handling
- HTTP server port conflicts show alert dialog and disable server in settings
- Core Audio errors print to console but don't crash app
- Unmanaged pointer operations in audio listener are wrapped in guard statements

## Key Files

- `Package.swift` - SPM manifest (Vapor dependency)
- `Package.resolved` - Locked dependency versions
- `ExportOptions.plist` - App export configuration for xcodebuild
- `MicToggle/App/MicToggleApp.swift` - SwiftUI app entry point
- `MicToggle/App/AppDelegate.swift` - NSApplicationDelegate lifecycle
- `MicToggle/Resources/Assets.xcassets/` - App icons

## Dependencies

- **Vapor 4.89.0+**: Full-featured web framework
  - Includes NIO (async I/O), routing, middleware
  - Heavy dependency but provides robust HTTP server

## macOS Requirements

- **Minimum**: macOS 13.0 (Ventura) for SMAppService
- **Microphone Permission**: Must be granted in System Settings → Privacy & Security
- **Gatekeeper**: Unsigned app requires `xattr -cr` to run
