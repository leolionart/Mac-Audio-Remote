# Update System Troubleshooting Guide

## Case Study: v2.7.0 → v2.8.1 DMG Mount Failure

### Timeline & Root Cause

**Date**: January 8, 2026
**Issue**: Users on v2.7.0 unable to update to v2.8.0/v2.8.1 - "Failed to mount DMG file" error
**Root Cause**: String interpolation bug in v2.7.0's UpdateManager.swift

### Technical Analysis

#### The Bug

In v2.7.0's `UpdateManager.swift:219-284`, the `prepareDMGInstall()` function had escaped string interpolation:

```swift
// WRONG - v2.7.0 code (literal backslash prevents interpolation)
_ = shell("xattr -cr '\\(dmgPath.path)'")
_ = shell("hdiutil attach -nobrowse '\\(dmgPath.path)'")
_ = shell("hdiutil detach '\\(volumePath)' -force")

// What shell receives:
// "xattr -cr '\(dmgPath.path)'"  ← Literal string, not the path!
```

**Expected behavior**:
```swift
// CORRECT - v2.8.1+ code
_ = shell("xattr -cr '\(dmgPath.path)'")
// Shell receives: "xattr -cr '/tmp/AudioRemote-2.8.1.dmg'"
```

#### Why v2.7.0 → v2.7.0 Worked But v2.7.0 → v2.8.x Failed

- **Commit 937c924** (in v2.7.1) attempted to fix APFS parsing but kept the `\\(` bug
- v2.7.0 release likely had users updating via ZIP (fallback), not DMG
- When v2.8.0+ were released with DMG-first preference, v2.7.0 apps tried DMG install
- v2.7.0's buggy code couldn't mount the DMG → update failed

#### The Migration Problem

**Critical Insight**: Even if v2.8.1 code is fixed, **users running v2.7.0 app still use v2.7.0 code** to perform the update!

```
┌─────────────────────────────────────────────────────┐
│ v2.7.0 App (buggy code)                             │
│  ↓ Downloads v2.8.1.dmg                             │
│  ↓ Tries to mount using v2.7.0's buggy shell()      │
│  ✗ FAILS - literal string '\(dmgPath.path)'         │
└─────────────────────────────────────────────────────┘

Solution: Remove DMG from v2.8.1 release
         → Force ZIP download
         → v2.7.0 app can handle ZIP
         → Update succeeds!

┌─────────────────────────────────────────────────────┐
│ v2.8.1 App (fixed code)                             │
│  ↓ Downloads v2.8.2.dmg                             │
│  ↓ Mounts using correct '\(dmgPath.path)'           │
│  ✓ SUCCESS!                                         │
└─────────────────────────────────────────────────────┘
```

### Solution Implemented

#### Step 1: Remove DMG from v2.8.1 Release

```bash
# Remove problematic DMG asset
gh release delete-asset v2.8.1 AudioRemote-2.8.1.dmg --yes

# Verify only ZIP remains
gh release view v2.8.1 --json assets --jq '.assets[].name'
# Output: AudioRemote-2.8.1.zip
```

**Rationale**:
- v2.7.0 app's `UpdateChecker` prefers DMG, falls back to ZIP if DMG unavailable
- By removing DMG, we force v2.7.0 apps to use ZIP install path
- ZIP install path doesn't have the `\\(` bug in v2.7.0 code

#### Step 2: Fix Code in v2.8.1

Fixed in `AudioRemote/Core/UpdateManager.swift:219-302`:

```swift
private func prepareDMGInstall(dmgPath: URL) -> InstallResult {
    // 1. Correct string interpolation (no backslash)
    _ = shell("xattr -cr '\(dmgPath.path)'")

    // 2. Mount with device output
    let attachOutput = shell("hdiutil attach -nobrowse -noverify '\(dmgPath.path)'")

    // 3. Parse BOTH device and volume paths
    var devicePath: String?
    var volumePath: String?
    let lines = attachOutput.output.components(separatedBy: "\n").filter { !$0.isEmpty }
    for line in lines.reversed() {
        if line.contains("/Volumes/") {
            let fields = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if fields.count >= 2,
               fields[0].hasPrefix("/dev/"),
               let volPath = fields.last(where: { $0.hasPrefix("/Volumes/") }) {
                devicePath = fields[0]
                volumePath = volPath
                break
            }
        }
    }

    // 4. Unmount using device path (more reliable)
    _ = shell("hdiutil detach '\(device)' -force")
}
```

**Key improvements**:
- ✅ Correct string interpolation (`\(var)` not `\\(var)`)
- ✅ Device path tracking for reliable unmount
- ✅ Robust APFS/HFS+ output parsing
- ✅ Better error messages with actual output

#### Step 3: Migration Path

```
v2.7.0 (buggy DMG code)
    ↓ Update via ZIP (v2.8.1 DMG removed)
v2.8.1 (fixed DMG code, ZIP-only release)
    ↓ Future updates can use DMG
v2.8.2+ (DMG preferred, normal releases)
```

### Prevention Guidelines

#### 1. String Interpolation Best Practices

**❌ WRONG**:
```swift
// Double backslash creates literal string
shell("command '\\(variable)'")  // → shell sees '\(variable)'
```

**✅ CORRECT**:
```swift
// Single backslash for interpolation
shell("command '\(variable)'")  // → shell sees actual value
```

**Testing**:
```swift
// Always test shell commands with print before executing
let cmd = "xattr -cr '\(dmgPath.path)'"
print("DEBUG: \(cmd)")  // Verify interpolation worked
_ = shell(cmd)
```

#### 2. Release Asset Order Matters

The `UpdateChecker` prefers DMG over ZIP:

```swift
// First pass: look for DMG
for asset in assets {
    if name.hasSuffix(".dmg") {
        isDMG = true
        break
    }
}

// Second pass: fallback to ZIP
if downloadURL == nil {
    for asset in assets {
        if name.hasSuffix(".zip") { ... }
    }
}
```

**Implication**: If there's a critical bug in DMG handling, you MUST either:
1. Remove DMG from release (force ZIP usage)
2. Upload ZIP first (GitHub API returns assets in upload order)

#### 3. Testing Update Flow

**CRITICAL**: Always test with the **PREVIOUS version's app**, not the new build!

```bash
# Wrong approach:
./build/release/AudioRemote.app  # New build
# Click "Check for Updates"
# ✗ This tests NEW code updating to NEW code (useless)

# Correct approach:
/Applications/AudioRemote.app  # Old installed version
# Click "Check for Updates"
# ✓ This tests OLD code updating to NEW code (realistic)
```

**Test matrix**:
- [ ] Previous version → New version (ZIP)
- [ ] Previous version → New version (DMG, if supported)
- [ ] DMG mount/unmount on both HFS+ and APFS
- [ ] Quarantine removal verification

#### 4. Backwards Compatibility Checklist

Before releasing updates with new install mechanisms:

- [ ] Can previous version's code handle the new release format?
- [ ] If new format fails, is there a fallback?
- [ ] Are error messages detailed enough for debugging?
- [ ] Can we force a specific format (ZIP/DMG) if needed?

#### 5. DMG Testing Commands

Test DMG mounting manually before release:

```bash
# Test mount
hdiutil attach -nobrowse -noverify YourApp.dmg

# Verify output format (APFS vs HFS+)
# APFS example:
# /dev/disk9s1    41504653-0000-11AA-AA11-0030654    /Volumes/YourApp

# HFS+ example:
# /dev/disk4s2    Apple_HFS    /Volumes/YourApp

# Parse test
OUTPUT=$(hdiutil attach ...)
echo "$OUTPUT" | grep "/Volumes/" | tail -1

# Clean unmount test
DEVICE=$(echo "$OUTPUT" | grep "/Volumes/" | awk '{print $1}')
hdiutil detach "$DEVICE" -force
```

### Release Checklist

Use this checklist for every release with update system changes:

#### Pre-Release Testing

- [ ] Build new version locally
- [ ] Install PREVIOUS version in /Applications
- [ ] Test update flow: Previous → New
- [ ] Verify both DMG and ZIP downloads work
- [ ] Test DMG mount on APFS (modern Macs)
- [ ] Test DMG mount on HFS+ (if supporting older systems)
- [ ] Check quarantine removal works
- [ ] Verify app relaunch works
- [ ] Test Settings window reopens after update

#### Code Review

- [ ] No `\\(variable)` in shell commands (use `\(variable)`)
- [ ] Device paths used for unmount, not volume paths
- [ ] Error messages include actual command output for debugging
- [ ] Fallback mechanisms in place (DMG → ZIP)
- [ ] Graceful failure handling (don't fail on minor errors)

#### Release Preparation

- [ ] Generate release notes (automated or manual)
- [ ] Build artifacts: DMG + ZIP
- [ ] Test artifacts locally before upload
- [ ] Upload assets in correct order (ZIP first if DMG might fail)
- [ ] Verify GitHub Release API response shows correct order

#### Post-Release Verification

- [ ] Check GitHub Release page shows both assets
- [ ] Curl GitHub API to verify asset order
- [ ] Test update check from previous version
- [ ] Monitor for update-related issues in first 24 hours

### Debugging Update Failures

If users report update failures:

1. **Get version info**:
   - What version are they running?
   - What version are they trying to update to?

2. **Check release assets**:
   ```bash
   curl -s "https://api.github.com/repos/USER/REPO/releases" | \
     jq '.[0] | {tag_name, assets: [.assets[] | .name]}'
   ```

3. **Verify asset preference**:
   - Is DMG listed first? (preferred by UpdateChecker)
   - Is there a fallback ZIP?

4. **Test locally**:
   - Download both DMG and ZIP
   - Test mount manually: `hdiutil attach DMG_PATH`
   - Check for quarantine: `xattr -l FILE`

5. **Emergency fix**:
   - Remove problematic asset from release
   - Force users to use known-working format
   - Release fixed version ASAP

### Historical Context

| Version | DMG Support | Issue | Resolution |
|---------|-------------|-------|------------|
| v2.6.x | ZIP only | N/A | Working |
| v2.7.0 | DMG added (buggy) | String interpolation `\\(var)` | Worked because users used ZIP fallback |
| v2.7.1 | DMG (still buggy) | APFS parsing attempted but `\\(` kept | Some updates failed |
| v2.8.0 | DMG (still buggy) | Inherited v2.7.0 bug | Updates from v2.7.0 failed |
| v2.8.1 | ZIP only (DMG removed) | Fixed code but removed DMG asset | ✅ Migration path for v2.7.0 users |
| v2.8.2+ | DMG + ZIP | N/A | Normal operations (most users on fixed v2.8.1) |

### Lessons Learned

1. **Code in running app matters more than code in new release** for update mechanism
2. **Always test with previous version**, not new build
3. **String interpolation is NOT the same as escape sequences** in Swift
4. **GitHub Release asset order affects which file is downloaded**
5. **Maintain backwards compatibility in update mechanism** - breaking it locks users out
6. **Have fallback formats** (DMG + ZIP) for maximum compatibility
7. **Emergency asset removal** is a valid mitigation strategy

### References

- Swift String Interpolation: [Official Docs](https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html)
- hdiutil man page: `man hdiutil`
- GitHub Releases API: [REST API Docs](https://docs.github.com/en/rest/releases)
- APFS vs HFS+ volume formats: `diskutil info /`
