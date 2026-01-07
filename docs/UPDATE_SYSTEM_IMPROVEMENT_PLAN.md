# Migrate Audio Remote Update System to DMG + Rust FFI

## Overview

Migrate Audio Remote's update system to use DMG format (learning from Gõ Nhanh) and add Rust FFI for robust version comparison. **Root cause of current install failure**: macOS quarantine attribute blocks unsigned app after unzip.

## User Requirements

- ✅ Switch ZIP → DMG format
- ✅ Add Rust FFI for version comparison
- ✅ Fix install failure (quarantine issue)
- ✅ Adopt proven patterns from successful implementations

## Root Cause Analysis

**Why Updates Fail Currently:**
1. Downloaded ZIP has `com.apple.quarantine` extended attribute
2. Extracted app inherits quarantine
3. `open` command fails (app is unsigned + quarantined)
4. **Missing**: `xattr -cr` to remove quarantine before launch

**Secondary Issues:**
- Race condition: `sleep 1` may not be enough on slow Macs
- Prefers ZIP over DMG (backwards from macOS standard)
- Naive version comparison fails edge cases ("2.10.0" vs "2.9.0")

## Implementation Phases

### Phase 1: Add Rust FFI for Version Comparison (16-20 hours)

**Why Rust?**
- Swift `.compare()` fails: "2.10.0" vs "2.9.0" (lexical issue)
- Proven to work in production (reference implementation)
- Rust `semver` crate handles all edge cases

**New Files:**
```
AudioRemote/RustFFI/
├── Cargo.toml              # Rust manifest (staticlib)
├── src/lib.rs              # FFI: version_compare, version_has_update
└── build.sh                # Compile to universal .a library
AudioRemote/Core/
└── RustBridge.h            # C header for Swift FFI
```

**Rust FFI Functions:**
```rust
// Returns: -1 (v1 < v2), 0 (equal), 1 (v1 > v2), -999 on error
pub extern "C" fn version_compare(v1: *const c_char, v2: *const c_char) -> i32

// Returns: true if latest > current
pub extern "C" fn version_has_update(current: *const c_char, latest: *const c_char) -> bool
```

**Swift Integration:**
- Import via `RustBridge.h`
- Call in `UpdateChecker.compareVersions()`
- Fallback to Swift if FFI fails

**Build Integration:**
1. `scripts/build_app_bundle.sh` calls `AudioRemote/RustFFI/build.sh`
2. Compiles for x86_64 + aarch64
3. Creates universal binary via `lipo`
4. `Package.swift` links via `-laudioremote_ffi`

### Phase 2: Switch to DMG Install (20-24 hours)

**UpdateChecker Changes:**
```swift
// Prefer DMG over ZIP (reverse current logic)
// Line 118-132: Find DMG first, fallback to ZIP
// Add isDMG: Bool to UpdateInfo struct
```

**UpdateManager Changes:**
```swift
// New method: installFromDMG(dmgPath:)
// New method: prepareDMGInstall(dmgPath:) -> InstallResult

Install Flow:
1. xattr -cr <DMG>                    # Strip quarantine from DMG
2. hdiutil attach -nobrowse           # Mount DMG
3. Parse mount point from stdout      # e.g., /Volumes/AudioRemote
4. Find AudioRemote.app in mount
5. cp -R to /tmp/AudioRemote-new.app
6. xattr -cr <NEW_APP>                # Strip quarantine from app
7. hdiutil detach                     # Unmount DMG
8. Improved relaunch script
```

**Improved Relaunch Script:**
```bash
# Replace sleep 1 with pgrep polling (up to 5 sec)
for i in {1..10}; do
    if ! pgrep -f "AudioRemote" > /dev/null; then
        break
    fi
    sleep 0.5
done

rm -rf <OLD_APP>
mv <NEW_APP> <OLD_APP>
xattr -cr <OLD_APP>  # Final strip (belt and suspenders)
open <OLD_APP>
```

**Keep ZIP as Fallback:**
- If download is ZIP, use existing `install(zipPath:)`
- Track format via `downloadingIsDMG` property

### Phase 3: Settings Reopen Flag (2 hours)

**Implementation:**

`UpdateManager.relaunchWithNewApp()`:
```swift
UserDefaults.standard.set(true, forKey: "audioremote.reopenSettings")
UserDefaults.standard.synchronize()  // Force write before terminate
NSApp.terminate(nil)
```

`AppDelegate.applicationDidFinishLaunching()`:
```swift
if UserDefaults.standard.bool(forKey: "audioremote.reopenSettings") {
    UserDefaults.standard.removeObject(forKey: "audioremote.reopenSettings")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.menuBarController?.showSettings()
    }
}
```

### Phase 4: Release Process Updates (3-4 hours)

**scripts/release.sh:**
- Create DMG **before** ZIP (prefer DMG)
- Upload DMG as first asset to GitHub Release
- Keep ZIP as secondary artifact

**scripts/build_app_bundle.sh:**
- Add Rust build step before Swift build:
```bash
./AudioRemote/RustFFI/build.sh
swift build -c release
```

## Critical Files to Modify

### Must Modify
1. `AudioRemote/Core/UpdateManager.swift` (267 lines)
   - Add `installFromDMG()`, `prepareDMGInstall()`
   - Improve relaunch script (pgrep polling, triple xattr)
   - Add `downloadingIsDMG` property

2. `AudioRemote/Core/UpdateChecker.swift` (170 lines)
   - Reverse preference: DMG first, ZIP fallback
   - Integrate Rust FFI: `compareVersions()` calls `version_compare()`
   - Add `isDMG: Bool` to `UpdateInfo`

3. `scripts/build_app_bundle.sh`
   - Call `AudioRemote/RustFFI/build.sh` before `swift build`

4. `scripts/release.sh`
   - Ensure DMG created before ZIP
   - Upload order: DMG, then ZIP

5. `Package.swift`
   - Add linker flags: `-L AudioRemote/RustFFI -laudioremote_ffi`

### Must Create
1. `AudioRemote/RustFFI/Cargo.toml`
2. `AudioRemote/RustFFI/src/lib.rs`
3. `AudioRemote/RustFFI/build.sh`
4. `AudioRemote/Core/RustBridge.h`
5. `Tests/AudioRemoteTests/RustFFITests.swift` (unit tests)

## Testing Strategy

### Unit Tests
```swift
// RustFFITests.swift
XCTAssertEqual(version_compare("2.6.0", "2.5.0"), 1)
XCTAssertEqual(version_compare("2.10.0", "2.9.0"), 1)  // Edge case
XCTAssertEqual(version_compare("v2.6.0", "2.5.0"), 1)  // 'v' prefix
```

### Integration Tests (Manual)
- [ ] Build Rust FFI on clean Mac
- [ ] Download DMG, verify mount/unmount
- [ ] Install from DMG, verify **no quarantine warning**
- [ ] Update 2.6.1 → 2.7.0 end-to-end
- [ ] Settings reopen after update
- [ ] Fallback to ZIP if DMG unavailable
- [ ] Test on macOS 13 (Intel), macOS 14 (M1)

## Risk Mitigation

### Critical Risks
| Risk | Mitigation |
|------|------------|
| Rust build fails | Keep ZIP fallback; Swift comparison fallback |
| DMG mount hangs | Add timeout; fallback to ZIP |
| Quarantine persists | Triple-strip (DMG, copy, final) |
| FFI crashes | Fallback to Swift; extensive testing |

### Rollback Strategy
- Phase 1 failure: Skip Rust, use Swift comparison
- Phase 2 failure: Keep ZIP-only
- Production issues: Release v2.6.3 reverting to ZIP

## Timeline

**Week 1**: Rust FFI (16-20h)
**Week 2**: DMG install (20-24h)
**Week 3**: Integration + testing (12-16h)
**Week 4**: Beta → production (8h)

**Total**: 56-68 hours (7-8.5 days)

## Success Criteria

**Phase 1:**
- [ ] Rust compiles to universal `.a`
- [ ] Swift calls FFI without crashes
- [ ] Version comparison passes all tests

**Phase 2:**
- [ ] DMG mounts successfully
- [ ] No quarantine warnings on launch
- [ ] Detach cleans up properly

**Phase 3:**
- [ ] Settings window opens after update
- [ ] Flag removed after opening

**Phase 4:**
- [ ] DMG upload to GitHub successful
- [ ] Update flow works end-to-end
- [ ] No user-reported install failures

## Key Implementation Insights

1. **Triple Quarantine Removal**: Strip DMG, app copy, final launch
2. **Improved Timing**: Poll `pgrep` instead of `sleep 1`
3. **DMG is macOS Standard**: More native than ZIP
4. **Rust FFI**: Proven approach for cross-platform semver

---

*Implementation Plan v2.0*
*Last Updated: 2026-01-07*
*Target Release: v2.7.0*
