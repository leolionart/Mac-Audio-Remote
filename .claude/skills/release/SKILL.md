---
name: release
description: >-
  Release workflow for Audio Remote macOS app using DMG distribution and Rust FFI version comparison.
  Handles version bump, Rust FFI build, DMG/ZIP creation, git tag, and GitHub Release.
  All builds happen locally - GitHub Actions only runs CI tests.
user_invocable: true
user_invocable_example: "/release 2.7.0"
---

# Audio Remote Release Process

This skill handles the complete release workflow for Audio Remote with DMG distribution and custom GitHub Releases update system.

## Workflow Overview

```
1. Commit changes → 2. Bump version → 3. Build (Rust + Swift) → 4. Create DMG + ZIP → 5. Push + Tag → 6. GitHub Release
```

**IMPORTANT**: All builds happen LOCALLY using `scripts/release.sh`. GitHub Actions release.yml is DISABLED.

## Quick Release Command

When user invokes `/release <version>`:

```bash
# Example: /release 2.7.0
./scripts/release.sh 2.7.0 "✨ New: Feature" "🔧 Fix: Bug fix"
```

## Architecture Changes (v2.7.0+)

- ✅ **Custom Update System**: Replaced Sparkle with custom GitHub Releases integration
- ✅ **DMG Distribution**: Primary format (ZIP as fallback for compatibility)
- ✅ **Rust FFI**: Robust semantic version comparison
- ✅ **Quarantine Removal**: Triple `xattr -cr` for unsigned app installation
- ❌ **No appcast.xml**: UpdateChecker queries GitHub Releases API directly
- ❌ **No EdDSA Signing**: Not needed for custom update system

## Step-by-Step Process

### 1. Pre-flight Checks

```bash
# Check for uncommitted changes
git status --porcelain

# Check current version
defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString
defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion

# Verify Rust is installed
rustc --version
cargo --version
```

**If Rust not installed**:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-apple-darwin aarch64-apple-darwin
```

### 2. Commit Outstanding Changes

If there are uncommitted changes, commit them first with a descriptive message.

### 3. Update Version in Info.plist

```bash
NEW_VERSION="2.7.0"  # From user input
CURRENT_BUILD=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion)
NEW_BUILD=$((CURRENT_BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "AudioRemote/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "AudioRemote/Resources/Info.plist"
```

### 4. Build App Bundle (Rust FFI + Swift)

```bash
./scripts/build_app_bundle.sh
```

This script:
1. **Builds Rust FFI** (`AudioRemote/RustFFI/build.sh`):
   - Compiles for x86_64-apple-darwin
   - Compiles for aarch64-apple-darwin
   - Creates universal binary with `lipo`
   - Output: `AudioRemote/RustFFI/libaudioremote_ffi.a`

2. **Builds Swift** (`swift build -c release`):
   - Links Rust library via `Package.swift`
   - Creates `.build/release/AudioRemote` binary

3. **Creates app bundle**:
   - Copies binary to `AudioRemote.app/Contents/MacOS/`
   - Copies Info.plist and resources
   - Output: `.build/release/AudioRemote.app`

### 5. Create DMG and ZIP

```bash
cd .build/release

# 1. Create DMG (primary distribution format)
../../scripts/create_dmg.sh
mv AudioRemote.dmg "AudioRemote-${NEW_VERSION}.dmg"

# DMG includes:
# - AudioRemote.app
# - Symlink to /Applications (for drag-and-drop)
# - Custom window styling
# - Compressed UDZO format

# 2. Create ZIP (fallback for compatibility)
zip -r "AudioRemote-${NEW_VERSION}.zip" AudioRemote.app
```

### 6. Commit Release Changes

```bash
git add AudioRemote/Resources/Info.plist
git commit -m "chore: Release v${NEW_VERSION}

- ✨ New: Feature 1
- 🔧 Fix: Bug fix 1"
```

### 7. Push and Create Tag

```bash
git push origin main

# Delete existing tag if it exists (for re-releases)
git tag -d "v${NEW_VERSION}" 2>/dev/null || true
git push origin ":refs/tags/v${NEW_VERSION}" 2>/dev/null || true

# Create and push new tag
git tag "v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"
```

### 8. Create GitHub Release

```bash
gh release create "v${NEW_VERSION}" \
  ".build/release/AudioRemote-${NEW_VERSION}.dmg" \
  ".build/release/AudioRemote-${NEW_VERSION}.zip" \
  --title "v${NEW_VERSION}" \
  --notes "$(cat <<'EOF'
## 🔧 Audio Remote v${NEW_VERSION}

### What's New
- ✨ New: Feature 1
- 🔧 Fix: Bug fix 1

### Installation
1. Download `AudioRemote-${NEW_VERSION}.dmg` below
2. Open the DMG file
3. Drag **AudioRemote** to the **Applications** folder
4. Launch the app from Applications
5. Grant necessary permissions when prompted

### Requirements
- macOS 13.0 (Ventura) or later
- Microphone permission (for mic toggle)
- Notification permission (for audio notifications)

### iOS Shortcuts Integration
Control your Mac remotely via HTTP:
```
POST http://YOUR_MAC_IP:8765/toggle-mic       # Toggle microphone
POST http://YOUR_MAC_IP:8765/volume/increase   # Increase volume
POST http://YOUR_MAC_IP:8765/volume/decrease   # Decrease volume
POST http://YOUR_MAC_IP:8765/volume/toggle-mute # Mute/unmute
GET  http://YOUR_MAC_IP:8765/status            # Get current status
```

For setup guide, see [iOS Shortcuts Documentation](https://github.com/leolionart/Mac-Audio-Remote/blob/main/docs/iOS-Shortcuts-Guide.md).
EOF
)"
```

**CRITICAL**: Upload order matters!
- DMG uploaded **first** (UpdateChecker prefers DMG)
- ZIP uploaded second (backward compatibility)

## Release Notes Format

Use these emoji prefixes:
- `✨ New:` - New features
- `🔧 Fix:` - Bug fixes
- `🎯 Enhanced:` - Improvements
- `🗑️ Removed:` - Removed features
- `⚠️ Breaking:` - Breaking changes

## Version Numbering

Follow semantic versioning:
- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Verification After Release

### 1. Check GitHub Release
```bash
open "https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v${NEW_VERSION}"
```

Verify:
- ✅ DMG is first asset (preferred by UpdateChecker)
- ✅ ZIP is second asset (fallback)
- ✅ Release notes are properly formatted

### 2. Test DMG Download
```bash
curl -L "https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/AudioRemote-${NEW_VERSION}.dmg" -o /tmp/test.dmg

# Mount and verify
hdiutil attach /tmp/test.dmg
ls -la /Volumes/AudioRemote/
hdiutil detach /Volumes/AudioRemote
```

### 3. Test Update Check
1. Open current version of Audio Remote
2. Go to Settings → About → Check for Updates
3. Should detect new version and offer DMG download
4. Click "Update & Install"
5. Verify:
   - DMG downloads successfully
   - App mounts DMG without quarantine warning
   - App replaces itself and relaunches
   - Settings window reopens automatically

### 4. Verify GitHub API Response
```bash
curl -s "https://api.github.com/repos/leolionart/Mac-Audio-Remote/releases" | jq '.[0] | {tag_name, assets: [.assets[] | {name, browser_download_url}]}'
```

Should show DMG first, then ZIP.

## Update Flow (How Users Get Updates)

### Automatic Check (Silent)
- Runs on app launch if 24+ hours since last check
- Queries GitHub Releases API
- Skipped versions stored in UserDefaults

### Manual Check (Settings)
- User clicks "Check for Updates" in Settings
- Shows update dialog if available
- User clicks "Update & Install"

### Install Process
1. Download DMG from GitHub Releases
2. Strip quarantine: `xattr -cr <DMG>`
3. Mount DMG: `hdiutil attach -nobrowse`
4. Copy app to temp: `/tmp/AudioRemote-new.app`
5. Strip quarantine: `xattr -cr <NEW_APP>`
6. Unmount DMG: `hdiutil detach`
7. Set reopen flag: `UserDefaults.standard.set(true, forKey: "audioremote.reopenSettings")`
8. Terminate app
9. Relaunch script:
   - Poll `pgrep` (up to 5 seconds)
   - Replace old app: `rm -rf <OLD> && mv <NEW> <OLD>`
   - Final quarantine strip: `xattr -cr <OLD>`
   - Launch: `open <OLD>`
10. New app opens, Settings window reopens automatically

## Troubleshooting

### Update Check Fails
```bash
# Test GitHub API manually
curl -s "https://api.github.com/repos/leolionart/Mac-Audio-Remote/releases" | jq '.[0].tag_name'

# Check app's current version
defaults read /Applications/AudioRemote.app/Contents/Info.plist CFBundleShortVersionString
```

### Quarantine Warning on Install
If users see "AudioRemote is damaged and can't be opened":
```bash
# Manual fix (users should NOT need this if triple xattr works)
xattr -cr /Applications/AudioRemote.app
```

Root cause: One of the three xattr removals failed.

### Rust FFI Build Fails
```bash
# Check Rust installation
rustc --version
cargo --version

# Check targets
rustup target list | grep installed

# Add missing targets
rustup target add x86_64-apple-darwin aarch64-apple-darwin

# Test build
cd AudioRemote/RustFFI
./build.sh
```

### Version Comparison Not Working
The Rust FFI handles version comparison. Test it:
```bash
# Should be available after build
cd AudioRemote/RustFFI
cargo test
```

## Files Modified by Release Process

- `AudioRemote/Resources/Info.plist` - Version bump
- `.build/release/AudioRemote.app` - Built app bundle
- `.build/release/AudioRemote-${VERSION}.dmg` - DMG artifact
- `.build/release/AudioRemote-${VERSION}.zip` - ZIP artifact

## Files NOT Modified (vs Old Sparkle Workflow)

- ❌ `appcast.xml` - No longer used
- ❌ EdDSA signatures - No longer needed
- ❌ `Sparkle.framework` - Removed from app bundle

## Key Implementation Files

- `AudioRemote/Core/UpdateChecker.swift` - GitHub API integration, DMG preference
- `AudioRemote/Core/UpdateManager.swift` - DMG install, quarantine removal
- `AudioRemote/RustFFI/` - Version comparison FFI
- `scripts/build_app_bundle.sh` - Rust + Swift build
- `scripts/create_dmg.sh` - DMG creation
- `scripts/release.sh` - Full release automation
