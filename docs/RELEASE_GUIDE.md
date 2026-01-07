# Audio Remote - Release Guide

## Overview

This guide provides instructions for releasing new versions of Audio Remote. The release process is fully automated via `scripts/release.sh`, which handles version bumping, building, and publishing to GitHub Releases.

The app uses a custom update mechanism that checks GitHub Releases directly, so no `appcast.xml` or EdDSA signing is required for updates to work.

## Prerequisites

- ✅ GitHub CLI (`gh`) installed and authenticated
- ✅ All code changes committed
- ✅ App tested locally
- ✅ Write access to the GitHub repository

## Release Process

### Automated Release (Recommended)

Run the interactive release script:

```bash
./scripts/release.sh
```

The script will:
1. Perform pre-flight checks (gh CLI, git status)
2. Ask for new version number
3. Collect release notes
4. Update `Info.plist`
5. Build the app bundle
6. Create ZIP archive
7. Commit and tag changes
8. Create GitHub Release

### Manual Release Steps (Reference)

If the script fails or you need to do it manually:

1.  **Update Version**: Edit `AudioRemote/Resources/Info.plist` (CFBundleShortVersionString and CFBundleVersion).
2.  **Build**: Run `./scripts/build_app_bundle.sh`.
3.  **Zip**: Compress `.build/release/AudioRemote.app` to `AudioRemote-X.Y.Z.zip`.
4.  **Tag**: Git commit and tag `vX.Y.Z`.
5.  **Release**: Create a new Release on GitHub, attach the ZIP, and publish.

## Auto-Update Flow

1.  **Check**: App queries GitHub Releases API (`https://api.github.com/repos/leolionart/Mac-Audio-Remote/releases`).
2.  **Compare**: App compares its version with the latest release tag (e.g., `v2.2.0` vs `2.1.0`).
3.  **Notify**: If a new version is found, user is notified.
4.  **Download & Install**: App downloads ZIP, extracts it, and swaps the app bundle.

## Troubleshooting

-   **Build fails**: Run `swift package clean` and try again.
-   **Release script fails**: Check if `gh` is logged in (`gh auth status`).
