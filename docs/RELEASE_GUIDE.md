# Audio Remote - Release Guide

## Quick Start

```bash
./scripts/release.sh <VERSION>
```

That's it! The script handles everything automatically.

## Prerequisites

- GitHub CLI (`gh`) installed: `brew install gh`
- Authenticated: `gh auth login`
- Rust installed (script will prompt if missing)

## What Happens

The script automatically:

1. Updates version in `Info.plist`
2. Builds Rust FFI + Swift app
3. Creates DMG (primary) and ZIP (fallback)
4. Commits, tags, and pushes to GitHub
5. Creates GitHub Release with both files

**No signing or appcast.xml needed** - app uses custom GitHub Releases integration.

## Version Numbers

Use semantic versioning:
- **2.7.1** - Bug fixes (PATCH)
- **2.8.0** - New features (MINOR)
- **3.0.0** - Breaking changes (MAJOR)

## Release Notes

Use emoji prefixes when prompted:
- `✨ New:` - New features
- `🔧 Fix:` - Bug fixes
- `🎯 Enhanced:` - Improvements
- `🗑️ Removed:` - Removed features

## How Updates Work

1. App checks GitHub Releases API (on launch if 24+ hours since last check)
2. Compares versions using Rust FFI
3. Downloads DMG (preferred) or ZIP
4. Auto-installs and relaunches

## Troubleshooting

**Rust not installed?**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

**Build fails?**
```bash
swift package clean
./scripts/release.sh <VERSION>
```

**Not logged into GitHub?**
```bash
gh auth login
```
