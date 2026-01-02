# Auto-Update Troubleshooting Guide

## Why Auto-Update Was Failing

### Problem 1: Missing EdDSA Signatures ❌
**Sparkle 2.0+ requires EdDSA signatures** for security verification.

**Symptoms:**
- Updates fail silently
- No error shown to user
- App says "Already up to date" even when newer version exists

**Solution:**
```xml
<enclosure url="..." 
           sparkle:edSignature="base64-signature-here"
           length="file-size" />
```

### Problem 2: Wrong pubDate ❌
Version 2.2.0 had an **older** pubDate than 2.1.2!

**Before:**
- v2.2.0: `Fri, 02 Jan 2026 17:53:48 GMT`
- v2.1.2: `Fri, 03 Jan 2026 00:10:00 GMT`

Sparkle thought v2.1.2 was newer!

**Fixed:**
- v2.2.0: `Fri, 03 Jan 2026 09:00:00 GMT` ✅

## How EdDSA Signing Works

### 1. Generate Key Pair (One Time)
```bash
./.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

Output:
```
A key has been generated and saved in your keychain.
SUPublicEDKey: yhe3Ngns1Q6TYa1KLZv2MXbQZRyPRyoqVzo+fQgqk0Q=
```

### 2. Add Public Key to Info.plist
```xml
<key>SUPublicEDKey</key>
<string>yhe3Ngns1Q6TYa1KLZv2MXbQZRyPRyoqVzo+fQgqk0Q=</string>
```

### 3. Sign Each Release
```bash
/tmp/bin/sign_update AudioRemote-2.2.0.zip
```

Output:
```
sparkle:edSignature="8xLxHKCBDo1G1vJSDFU9Pd/tVIEElTgjdrrtzKtIAbmvRmoxkHUZjwcp5qCib97jUwcHgEhHRFcgM4xuEzPOCA==" length="14290954"
```

### 4. Add Signature to appcast.xml
```xml
<enclosure url="https://github.com/leolionart/Mac-Audio-Remote/releases/download/v2.2.0/AudioRemote-2.2.0.zip"
           sparkle:version="2.2.0"
           sparkle:shortVersionString="2.2.0"
           sparkle:edSignature="8xLxHKCBDo1G1vJSDFU9Pd/tVIEElTgjdrrtzKtIAbmvRmoxkHUZjwcp5qCib97jUwcHgEhHRFcgM4xuEzPOCA=="
           length="14290954"
           type="application/octet-stream" />
```

## About DMG Files

### Why We Have Both ZIP and DMG

**ZIP File (AudioRemote-2.2.0.zip):**
- ✅ Used for auto-updates via Sparkle
- ✅ Smaller file size
- ✅ Faster to download
- ✅ Automatically signed with EdDSA

**DMG File (AudioRemote.dmg):**
- 📦 Used for initial manual installation
- 🎨 Can have custom installer UI
- ✅ macOS native disk image format
- ⚠️  Created by GitHub Actions, not release.sh

### How DMG is Created

The DMG is automatically created by GitHub Actions workflow (`.github/workflows/release.yml`) and uploaded to releases. It's NOT created by `release.sh`.

If you need to create DMG manually:
```bash
create-dmg \
  --volname "Audio Remote" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 425 120 \
  "AudioRemote.dmg" \
  ".build/release/AudioRemote.app"
```

## Testing Auto-Update

### From Version 2.1.2 to 2.2.0

1. Install v2.1.2:
```bash
open https://github.com/leolionart/Mac-Audio-Remote/releases/download/v2.1.2/AudioRemote-2.1.2.zip
```

2. Launch app and check version in About or Footer

3. Manually trigger update check:
   - Click Settings
   - Look for "Check for Updates" button
   - OR: Quit and relaunch app (checks on startup)

4. Expected result:
   - Update notification appears
   - Shows "Version 2.2.0 is now available"
   - Click "Install Update"
   - App downloads, quits, installs, relaunches
   - Verify version is now 2.2.0

### Debugging Update Issues

**Enable Sparkle debug logging:**
```bash
defaults write com.leolion.audioremote SUEnableDebugLogging YES
```

**Check logs:**
```bash
log stream --predicate 'subsystem == "org.sparkle-project.Sparkle"' --level debug
```

**Common issues:**
- ❌ `Signature validation failed` → EdDSA signature mismatch
- ❌ `No update available` → pubDate is older than current version
- ❌ `Update not found` → appcast.xml URL is wrong

## Release Checklist

When creating new release:
- [ ] Run `./release.sh` (auto-generates signature now)
- [ ] Verify appcast.xml has `sparkle:edSignature`
- [ ] Verify pubDate is AFTER previous release
- [ ] Verify file size matches actual ZIP
- [ ] Test update from previous version
- [ ] Check GitHub Actions created DMG

## Files Modified for Fix

1. **Info.plist** - Added SUPublicEDKey
2. **appcast.xml** - Added edSignature, fixed pubDate
3. **release.sh** - Auto-sign ZIP, generate signature
4. **AudioRemote-2.2.0.zip** - Re-uploaded with public key in bundle

## Verification

```bash
# Check public key in app
/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" .build/release/AudioRemote.app/Contents/Info.plist

# Expected: yhe3Ngns1Q6TYa1KLZv2MXbQZRyPRyoqVzo+fQgqk0Q=
```

```bash
# Check signature in appcast.xml
curl -s https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml | grep edSignature

# Expected: sparkle:edSignature="8xLxHKCBDo1G1vJSDFU9Pd/tVIEElTgjdrrtzKtIAbmvRmoxkHUZjwcp5qCib97jUwcHgEhHRFcgM4xuEzPOCA=="
```
