---
name: release
description: >-
  Fully automated release - auto-commits changes, auto-bumps version, auto-generates release notes, and publishes to GitHub.
user_invocable: true
user_invocable_example: "/release"
---

# Audio Remote - Automated Release

## Usage

```bash
/release
```

**That's it!** No arguments, no prompts, fully automated.

## What Happens Automatically

1. **Auto-commit** - Commits any uncommitted changes
2. **Auto-version** - Determines version bump from commit messages:
   - `MAJOR` - "breaking" or "major" in commits
   - `MINOR` - "feat", "new", or "✨" in commits
   - `PATCH` - everything else (default)
3. **Auto-release-notes** - Extracts from git commits since last tag
4. **Build & Publish** - Runs full release pipeline

## Commit Message Conventions

For best auto-detection, use conventional commits:
- `feat:` or `✨` → Minor version bump, "New" in release notes
- `fix:` or `🔧` → Patch version, "Fix" in notes
- `docs:` or `📝` → "Docs" in notes
- `perf:` or `⚡` → "Performance" in notes
- `breaking:` → Major version bump

## Manual Override (if needed)

If you need to specify version manually:
```bash
./scripts/release.sh <VERSION> "<note 1>" "<note 2>"
```

## Troubleshooting

**Rust not installed?** The script will prompt to install.

**Build fails?**
```bash
swift package clean
/release
```
