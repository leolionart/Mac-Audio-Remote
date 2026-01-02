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

**IMPORTANT**: This project uses GitHub Actions for automated building and releasing. **DO NOT manually build releases** unless absolutely necessary for testing. Always use the automated workflows to ensure consistency and proper versioning.

### GitHub Actions Workflows

**CI Workflow** (`.github/workflows/ci.yml`)
- **Triggers**: Push to `main` or `develop` branches, or pull requests
- **Purpose**: Continuous integration testing
- **Actions**:
  1. Checkout code
  2. Setup Xcode (latest stable)
  3. Cache Swift packages
  4. Build debug version
  5. Build release version
  6. Run tests (if any)
  7. Verify app bundle can be created

**Release Workflow** (`.github/workflows/release.yml`)
- **Triggers**:
  - Git tags matching `v*.*.*` pattern (e.g., `v2.0.0`, `v2.1.3`)
  - Manual dispatch from GitHub Actions tab
- **Purpose**: Build and publish releases
- **Actions**:
  1. Checkout code
  2. Setup Xcode (latest stable)
  3. Cache Swift packages
  4. Build release binary with `swift build -c release`
  5. Create app bundle structure:
     - `AudioRemote.app/Contents/MacOS/` (binary)
     - `AudioRemote.app/Contents/Resources/` (Info.plist, AppIcon.icns)
  6. Create DMG using `create-dmg` (with fallback to `hdiutil`)
  7. Create ZIP archive
  8. Create GitHub Release with:
     - DMG and ZIP attachments
     - Auto-generated release notes
     - Feature highlights
  9. Upload artifacts for manual runs (30-day retention)

### How to Release a New Version

**FOLLOW THIS PROCESS - DO NOT DEVIATE**

1. **Update Version Number**
   ```bash
   # Edit AudioRemote/Resources/Info.plist
   # Update CFBundleShortVersionString (e.g., "2.1.0")
   # Update CFBundleVersion (build number, e.g., "2")
   ```

2. **Update Changelog** (if exists)
   ```bash
   # Document new features, bug fixes, breaking changes
   # Follow Keep a Changelog format
   ```

3. **Commit Version Changes**
   ```bash
   git add AudioRemote/Resources/Info.plist
   git commit -m "chore: Bump version to 2.1.0"
   git push origin main
   ```

4. **Create and Push Git Tag**
   ```bash
   # Tag format MUST be v{major}.{minor}.{patch}
   git tag v2.1.0
   git push origin v2.1.0
   ```

5. **GitHub Actions Automatically**:
   - Detects the tag
   - Triggers release workflow
   - Builds DMG and ZIP
   - Creates GitHub Release
   - Uploads distribution files

6. **Verify Release**:
   - Check GitHub Actions workflow status
   - Verify release appears on GitHub Releases page
   - Test downloaded DMG/ZIP

### Manual Release (Emergency Only)

Only use if GitHub Actions is down or for local testing:

```bash
# Build release
swift build -c release

# Create app bundle (WITHOUT xcodebuild - it requires full Xcode)
mkdir -p AudioRemote.app/Contents/MacOS
mkdir -p AudioRemote.app/Contents/Resources

# Copy files
cp .build/release/AudioRemote AudioRemote.app/Contents/MacOS/
cp AudioRemote/Resources/Info.plist AudioRemote.app/Contents/
cp AudioRemote/Resources/AppIcon.icns AudioRemote.app/Contents/Resources/

# Make executable
chmod +x AudioRemote.app/Contents/MacOS/AudioRemote

# Create ZIP
zip -r AudioRemote.zip AudioRemote.app

# Create DMG (requires create-dmg or hdiutil)
hdiutil create -volname "Audio Remote" -srcfolder AudioRemote.app -ov -format UDZO AudioRemote.dmg
```

**⚠️ WARNING**: Manual builds:
- Will NOT appear in GitHub Releases
- Will NOT trigger Sparkle auto-update
- May have inconsistent versioning
- Should ONLY be used for local testing

### Version Numbering Convention

Follow Semantic Versioning (SemVer):
- **Major (X.0.0)**: Breaking changes, major rewrites
- **Minor (x.X.0)**: New features, backwards compatible
- **Patch (x.x.X)**: Bug fixes, minor improvements

Examples:
- `v2.0.0`: Swift rewrite (breaking change from Python version)
- `v2.1.0`: Added output volume control (new feature)
- `v2.1.1`: Fixed HTTP server crash (bug fix)

### Release Notes Guidelines

GitHub Actions auto-generates release notes with:
- Feature highlights (🎤 🔊 📱 🌐 ⚡️)
- Installation instructions
- Requirements
- Link to full changelog

For custom release notes, edit the workflow file `.github/workflows/release.yml` before tagging.

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
