---
name: release
description: >-
  Release new version of Audio Remote. Runs ./scripts/release.sh to build, package, and publish to GitHub Releases.
user_invocable: true
user_invocable_example: "/release 2.8.0"
---

# Audio Remote Release

## Usage

```bash
/release <VERSION>
```

This runs `./scripts/release.sh` which handles everything automatically.

## What the Script Does

1. Updates version in `Info.plist`
2. Builds Rust FFI + Swift app
3. Creates DMG and ZIP
4. Commits, tags, and pushes
5. Creates GitHub Release

**No signing, no appcast.xml needed** - app uses custom GitHub Releases integration.

## Release Notes Format

When prompted, use emoji prefixes:
- `✨ New:` - New features
- `🔧 Fix:` - Bug fixes
- `🎯 Enhanced:` - Improvements
- `🗑️ Removed:` - Removed features
- `⚠️ Breaking:` - Breaking changes

## Version Numbering

Use semantic versioning `MAJOR.MINOR.PATCH`:
- **PATCH** (2.7.1): Bug fixes only
- **MINOR** (2.8.0): New features, backward compatible
- **MAJOR** (3.0.0): Breaking changes

## Troubleshooting

**Rust not installed?**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup target add x86_64-apple-darwin aarch64-apple-darwin
```

**Build fails?**
```bash
swift package clean
./scripts/release.sh <VERSION>
```

**GitHub CLI not authenticated?**
```bash
gh auth login
```
