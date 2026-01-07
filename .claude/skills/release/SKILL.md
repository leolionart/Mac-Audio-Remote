---
name: release
description: >-
  Release workflow for Audio Remote macOS app. Use when releasing a new version.
  Handles version bump, build, EdDSA signing, appcast.xml update, git tag, and GitHub Release.
  All builds and signing happen locally - GitHub Actions only runs CI tests.
user_invocable: true
user_invocable_example: "/release 2.6.0"
---

# Audio Remote Release Process

This skill handles the complete release workflow for Audio Remote.

## Workflow Overview

```
1. Commit changes → 2. Bump version → 3. Build → 4. Sign ZIP → 5. Update appcast.xml → 6. Push + Tag → 7. GitHub Release
```

**IMPORTANT**: All builds and signing happen LOCALLY. GitHub Actions release.yml is DISABLED to avoid duplicate releases with mismatched signatures.

## Quick Release Command

When user invokes `/release <version>`:

```bash
# Example: /release 2.6.0
```

## Step-by-Step Process

### 1. Pre-flight Checks

```bash
# Check for uncommitted changes
git status --porcelain

# Check current version
defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString
defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion
```

### 2. Commit Outstanding Changes

If there are uncommitted changes, commit them first with a descriptive message.

### 3. Update Version in Info.plist

```bash
NEW_VERSION="2.6.0"  # From user input
CURRENT_BUILD=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion)
NEW_BUILD=$((CURRENT_BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "AudioRemote/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "AudioRemote/Resources/Info.plist"
```

### 4. Build App Bundle

```bash
./scripts/build_app_bundle.sh
```

This creates `.build/release/AudioRemote.app` with:
- Binary
- Info.plist
- Resources
- Sparkle.framework

### 5. Create and Sign ZIP

```bash
cd .build/release
zip -r "AudioRemote-${NEW_VERSION}.zip" AudioRemote.app
```

Sign with EdDSA (Sparkle):

```bash
# Download Sparkle tools if needed
curl -L -o /tmp/Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
tar xf /tmp/Sparkle.tar.xz -C /tmp

# Sign (uses private key from Keychain)
SIGNATURE_OUTPUT=$(/tmp/bin/sign_update "$(pwd)/.build/release/AudioRemote-${NEW_VERSION}.zip")

# Extract signature and length
ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
ZIP_SIZE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
```

### 6. Update appcast.xml

Insert new `<item>` after `<language>en</language>`:

```xml
<item>
    <title>Version ${NEW_VERSION}</title>
    <description><![CDATA[
            <h2>Version ${NEW_VERSION}</h2>
            <ul>
                <li>✨ New: Feature description</li>
                <li>🔧 Fix: Bug fix description</li>
                <li>🎯 Enhanced: Improvement description</li>
            </ul>
    ]]></description>
    <pubDate>${RFC822_DATE}</pubDate>
    <enclosure url="https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/AudioRemote-${NEW_VERSION}.zip"
               sparkle:version="${NEW_VERSION}"
               sparkle:shortVersionString="${NEW_VERSION}"
               sparkle:edSignature="${ED_SIGNATURE}"
               length="${ZIP_SIZE}"
               type="application/octet-stream" />
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
</item>
```

Date format for pubDate:
```bash
PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
```

### 7. Commit Release Changes

```bash
git add AudioRemote/Resources/Info.plist appcast.xml
git commit -m "chore: Release v${NEW_VERSION}

- ✨ New: Feature 1
- 🔧 Fix: Bug fix 1"
```

### 8. Push and Create Tag

```bash
git push origin main

# Create tag
git tag "v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"
```

### 9. Create GitHub Release

```bash
gh release create "v${NEW_VERSION}" \
  ".build/release/AudioRemote-${NEW_VERSION}.zip" \
  --title "v${NEW_VERSION}" \
  --notes "$(cat <<'EOF'
## Audio Remote v${NEW_VERSION}

### What's New
- ✨ Feature 1
- 🔧 Fix 1

### Installation
1. Download `AudioRemote-${NEW_VERSION}.zip`
2. Extract and move to Applications
3. Launch and grant permissions

### Auto-Update
Existing users will be notified via Sparkle.
EOF
)"
```

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

1. Check release on GitHub: `https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v${NEW_VERSION}`
2. Verify appcast.xml is updated: `curl https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml | head -30`
3. Test download: `curl -L https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/AudioRemote-${NEW_VERSION}.zip -o /tmp/test.zip`
4. Trigger update check in existing app: Settings → Check for Updates

## Troubleshooting

### Sparkle Update Not Working

1. **Check appcast.xml accessibility**:
   ```bash
   curl https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml
   ```

2. **Verify signature matches**:
   ```bash
   /tmp/bin/sign_update downloaded.zip
   # Compare with appcast.xml edSignature
   ```

3. **Check public key matches**:
   - App's Info.plist `SUPublicEDKey` must match signing key pair
   - Current public key: `SBT2krY3aqHgJZfp8ptMS8SjsplnHPWT33xDu4OGRmE=`

4. **Force update check**:
   - User must manually check (Settings → Check for Updates)
   - Or wait for `SUScheduledCheckInterval` (86400 seconds = 24 hours)

### GitHub Actions Conflict

GitHub Actions workflow at `.github/workflows/release.yml` is DISABLED by design.
The workflow would create duplicate releases with different signatures.

If it runs accidentally, delete the GitHub Actions-created assets and re-upload local ZIP.
