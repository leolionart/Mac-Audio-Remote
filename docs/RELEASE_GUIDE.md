# Audio Remote - Release Guide for AI Agents

## Overview

This guide provides step-by-step instructions for AI agents to perform a complete release of Audio Remote, from version updates to customer delivery via auto-update.

## Prerequisites

Before starting a release, ensure:
- ✅ GitHub CLI (`gh`) is installed and authenticated
- ✅ All code changes are committed
- ✅ App is tested and working locally
- ✅ You have write access to the GitHub repository

## Release Process

### Quick Release (Recommended)

Simply run the automated release script:

```bash
./release.sh
```

The script will guide you through:
1. Pre-flight checks (gh CLI, git status)
2. Version number input (semantic versioning)
3. Release notes collection
4. Info.plist update
5. Build and test
6. ZIP archive creation
7. Appcast.xml update
8. Git commit, tag, and push
9. GitHub Release creation

### Manual Release Steps

If you need to perform steps manually:

#### 1. Update Version

Edit `AudioRemote/Resources/Info.plist`:
```bash
# Update CFBundleShortVersionString to new version (e.g., 2.2.0)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 2.2.0" AudioRemote/Resources/Info.plist

# Increment CFBundleVersion (build number)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 4" AudioRemote/Resources/Info.plist
```

#### 2. Build App

```bash
./build_app_bundle.sh
```

Verify the app bundle:
```bash
ls -lh .build/release/AudioRemote.app/Contents/MacOS/AudioRemote
ls -lh .build/release/AudioRemote.app/Contents/Resources/AppIcon.icns
ls -lh .build/release/AudioRemote.app/Contents/Frameworks/Sparkle.framework
```

#### 3. Test App

```bash
open .build/release/AudioRemote.app
```

Verify:
- App launches without errors
- Icon displays correctly
- Menu bar icon appears
- HTTP server starts (port 8765)
- Volume and mic controls work

#### 4. Create ZIP Archive

```bash
cd .build/release
zip -r AudioRemote-2.2.0.zip AudioRemote.app
# Get file size for appcast
stat -f%z AudioRemote-2.2.0.zip
cd ../..
```

#### 5. Update appcast.xml

Add new `<item>` entry at the top (after `<language>en</language>`):

```xml
<item>
    <title>Version 2.2.0</title>
    <description><![CDATA[
        <h2>Version 2.2.0</h2>
        <ul>
            <li>✨ New: Feature description</li>
            <li>🔧 Fix: Bug fix description</li>
        </ul>
    ]]></description>
    <pubDate>Fri, 03 Jan 2026 12:00:00 GMT</pubDate>
    <enclosure url="https://github.com/leolionart/Mac-Audio-Remote/releases/download/v2.2.0/AudioRemote-2.2.0.zip"
               sparkle:version="2.2.0"
               sparkle:shortVersionString="2.2.0"
               length="FILE_SIZE_IN_BYTES"
               type="application/octet-stream" />
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
</item>
```

**Important:** Update `length` with actual file size from step 4.

#### 6. Commit and Tag

```bash
git add AudioRemote/Resources/Info.plist appcast.xml
git commit -m "chore: Release v2.2.0

- Feature 1
- Feature 2"

git tag v2.2.0
git push origin main
git push origin v2.2.0
```

#### 7. Create GitHub Release

```bash
gh release create v2.2.0 \
  .build/release/AudioRemote-2.2.0.zip \
  --title "v2.2.0" \
  --notes "## Audio Remote v2.2.0

### What's New
- Feature 1
- Feature 2

### Installation
1. Download AudioRemote-2.2.0.zip
2. Extract and move to Applications
3. Launch and grant permissions

See full documentation at https://github.com/leolionart/Mac-Audio-Remote"
```

## File Structure

```
mac-audio-remote/
├── release.sh                  # Automated release script
├── build_app_bundle.sh         # App bundle builder
├── appcast.xml                 # Sparkle update feed
├── AudioRemote/
│   └── Resources/
│       └── Info.plist          # Version info
└── .build/release/
    ├── AudioRemote.app         # Built app bundle
    └── AudioRemote-X.X.X.zip   # Release archive
```

## Release Checklist

Use this checklist when performing a release:

- [ ] All code changes committed
- [ ] Version number follows semantic versioning (X.Y.Z)
- [ ] Build number incremented
- [ ] App builds successfully
- [ ] App launches and works correctly
- [ ] Icon displays properly
- [ ] ZIP archive created with correct name
- [ ] appcast.xml updated with correct file size
- [ ] Git commit created with descriptive message
- [ ] Git tag created (vX.Y.Z)
- [ ] Tag pushed to GitHub
- [ ] GitHub Release created
- [ ] ZIP file uploaded to release
- [ ] Release notes are clear and descriptive
- [ ] Appcast.xml accessible at raw GitHub URL
- [ ] Tested auto-update from previous version

## Auto-Update Flow

When a release is published, existing users receive updates via this flow:

1. **User opens app** → Sparkle checks appcast.xml every 24 hours
2. **New version found** → Sparkle compares version numbers
3. **Update prompt** → User sees "A new version is available"
4. **Download** → Sparkle downloads ZIP from GitHub release
5. **Install** → Sparkle extracts and replaces app
6. **Relaunch** → App restarts with new version

## Troubleshooting

### "gh: command not found"
```bash
brew install gh
gh auth login
```

### Build fails
```bash
# Clean build directory
rm -rf .build
./build_app_bundle.sh
```

### Icon not showing
Verify AppIcon.icns is in Resources:
```bash
ls -lh .build/release/AudioRemote.app/Contents/Resources/AppIcon.icns
```

### Auto-update not working
1. Check appcast.xml is accessible:
   ```bash
   curl https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml
   ```
2. Verify file size in appcast.xml matches actual ZIP size
3. Ensure GitHub Release is published (not draft)
4. Check CFBundleIdentifier is consistent across versions

## Version Numbering

Use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR** (2.0.0): Breaking changes, major rewrites
- **MINOR** (2.1.0): New features, non-breaking changes
- **PATCH** (2.1.1): Bug fixes, small improvements

Build number increments with each release regardless of version.

## Release Notes Guidelines

Good release notes:
- ✅ Start with emoji (✨ New, 🔧 Fix, 🎯 Enhanced)
- ✅ Be concise and user-focused
- ✅ Highlight user-visible changes
- ✅ Group by category (New, Fixed, Improved)

Bad release notes:
- ❌ Technical jargon (refactored AudioManager.swift)
- ❌ Internal details (updated dependencies)
- ❌ Vague descriptions (various improvements)

## AI Agent Instructions

When asked to create a release:

1. **Ask for version number** if not provided
2. **Ask for release notes** if not clear from recent commits
3. **Run `./release.sh`** and follow the prompts
4. **Verify success** by checking:
   - GitHub Release exists
   - ZIP file is attached
   - appcast.xml is updated
   - Tag is pushed
5. **Inform user** of release URL and next steps

Example interaction:
```
User: "Create a new release with the bug fixes"

AI: "I'll create a release with the recent bug fixes.
     What version number should this be? (current: 2.1.1)"

User: "2.1.2"

AI: "Creating release v2.1.2 with bug fixes..."
    [runs ./release.sh]
    "✅ Release v2.1.2 complete!
     URL: https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v2.1.2
     Existing users will receive the update automatically via Sparkle."
```

## Emergency Rollback

If a release has critical issues:

1. Delete the GitHub release:
   ```bash
   gh release delete v2.2.0 --yes
   ```

2. Remove the git tag:
   ```bash
   git tag -d v2.2.0
   git push origin :refs/tags/v2.2.0
   ```

3. Revert appcast.xml:
   ```bash
   git revert HEAD
   git push origin main
   ```

This prevents new users from downloading the broken version and stops auto-updates.

## Support

- GitHub Issues: https://github.com/leolionart/Mac-Audio-Remote/issues
- Documentation: https://github.com/leolionart/Mac-Audio-Remote/blob/main/README.md
- iOS Shortcuts Guide: https://github.com/leolionart/Mac-Audio-Remote/blob/main/docs/iOS-Shortcuts-Guide.md
