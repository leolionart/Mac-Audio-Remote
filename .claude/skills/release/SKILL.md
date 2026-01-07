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

**That's it!** The script automates everything: version bump, Rust build, DMG/ZIP creation, git push, tagging, and GitHub release.

## Architecture Changes (v2.7.0+)

- ✅ **Custom Update System**: Replaced Sparkle with custom GitHub Releases integration
- ✅ **DMG Distribution**: Primary format (ZIP as fallback for compatibility)
- ✅ **Rust FFI**: Robust semantic version comparison
- ✅ **Quarantine Removal**: Triple `xattr -cr` for unsigned app installation
- ❌ **No appcast.xml**: UpdateChecker queries GitHub Releases API directly
- ❌ **No EdDSA Signing**: Not needed for custom update system

## Automated Release Process

### Overview

`./scripts/release.sh` is a **fully automated** script that handles the entire release workflow. You only need to:

1. **Pre-flight checks** (git status, Rust installed)
2. **Commit any uncommitted changes**
3. **Run the script** with version and release notes

The script then automates all remaining steps.

### Step 1: Pre-flight Checks

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
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup target add x86_64-apple-darwin
```

### Step 2: Commit Outstanding Changes

If there are uncommitted changes, commit them first with a descriptive message.

### Step 3: Run Release Script

```bash
./scripts/release.sh <VERSION> "<release note 1>" "<release note 2>" ...

# Example:
./scripts/release.sh 2.7.0 \
  "✨ New: DMG-based update system" \
  "✨ New: Rust FFI for version comparison" \
  "🗑️ Removed: Sparkle framework dependency"
```

**The script automatically performs ALL these steps:**

1. ✅ **Version Bump**: Updates `CFBundleShortVersionString` and `CFBundleVersion` in Info.plist
2. ✅ **Build Rust FFI**: Compiles universal binary (x86_64 + arm64) via `AudioRemote/RustFFI/build.sh`
3. ✅ **Build Swift**: Links Rust library and builds release binary
4. ✅ **Create App Bundle**: Packages binary with Info.plist and resources
5. ✅ **Create DMG**: Primary distribution format with Applications symlink
6. ✅ **Create ZIP**: Fallback format for compatibility
7. ✅ **Commit Changes**: Commits version bump with formatted release notes
8. ✅ **Push & Tag**: Pushes to origin and creates/pushes git tag
9. ✅ **GitHub Release**: Creates release with DMG (first) and ZIP (second) assets

**Upload Order (CRITICAL):**
- DMG uploaded **first** → UpdateChecker prefers DMG
- ZIP uploaded second → Backward compatibility fallback

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

The script outputs the release URL at the end:
```
✅ Release v2.7.0 Complete!
🔗 Release URL: https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v2.7.0
```

Or check manually:
```bash
gh release view v${NEW_VERSION} --json tagName,assets
```

Verify:
- ✅ DMG is first asset (preferred by UpdateChecker)
- ✅ ZIP is second asset (fallback)
- ✅ Release notes are properly formatted

### 2. Verify GitHub API Response

```bash
curl -s "https://api.github.com/repos/leolionart/Mac-Audio-Remote/releases" | jq '.[0] | {tag_name, assets: [.assets[] | {name, browser_download_url}]}'
```

Should show DMG first, then ZIP.

### 3. Test Update Check (Optional)

**Manual test on a real Mac:**
1. Open current version of Audio Remote
2. Go to Settings → About → Check for Updates
3. Should detect new version and offer DMG download
4. Click "Update & Install"
5. Verify:
   - DMG downloads successfully
   - App mounts DMG without quarantine warning
   - App replaces itself and relaunches
   - Settings window reopens automatically

**Note**: This requires running an older version, so it's optional for most releases.

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
