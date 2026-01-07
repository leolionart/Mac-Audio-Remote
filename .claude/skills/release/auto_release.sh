#!/bin/bash
# Auto Release Script - Fully automated release workflow
# No user input required

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🤖 Automated Release Workflow${NC}\n"

# 1. Auto-commit any uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${BLUE}[1/5] 📝 Auto-committing changes...${NC}"
    git add -A

    # Generate commit message from git diff summary
    CHANGED_FILES=$(git diff --cached --name-only | wc -l | tr -d ' ')
    git commit -m "chore: Auto-commit before release ($CHANGED_FILES files changed)"
    echo -e "${GREEN}✓ Committed $CHANGED_FILES files${NC}\n"
else
    echo -e "${BLUE}[1/5] ✓ No uncommitted changes${NC}\n"
fi

# 2. Get current version and auto-bump
echo -e "${BLUE}[2/5] 🔢 Determining version bump...${NC}"
CURRENT_VERSION=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.7.0")

# Get commits since last tag
COMMITS_SINCE=$(git log ${LAST_TAG}..HEAD --oneline)

# Auto-determine version bump based on commit messages
if echo "$COMMITS_SINCE" | grep -qi "breaking\|major"; then
    BUMP_TYPE="major"
elif echo "$COMMITS_SINCE" | grep -qi "feat\|new\|✨"; then
    BUMP_TYPE="minor"
else
    BUMP_TYPE="patch"
fi

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case $BUMP_TYPE in
    major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
    minor) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
    patch) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
esac

echo -e "${GREEN}✓ Auto-bump: $CURRENT_VERSION → $NEW_VERSION ($BUMP_TYPE)${NC}\n"

# 3. Auto-generate release notes from commits
echo -e "${BLUE}[3/5] 📋 Auto-generating release notes...${NC}"
RELEASE_NOTES=()

while IFS= read -r line; do
    # Extract commit message (remove hash)
    MSG=$(echo "$line" | cut -d' ' -f2-)

    # Categorize and format
    if echo "$MSG" | grep -qi "^feat\|^✨"; then
        RELEASE_NOTES+=("✨ New: ${MSG#*: }")
    elif echo "$MSG" | grep -qi "^fix\|^🔧"; then
        RELEASE_NOTES+=("🔧 Fix: ${MSG#*: }")
    elif echo "$MSG" | grep -qi "^docs\|^📝"; then
        RELEASE_NOTES+=("📝 Docs: ${MSG#*: }")
    elif echo "$MSG" | grep -qi "^perf\|^⚡"; then
        RELEASE_NOTES+=("⚡ Performance: ${MSG#*: }")
    elif echo "$MSG" | grep -qi "^refactor\|^♻️"; then
        RELEASE_NOTES+=("♻️ Refactor: ${MSG#*: }")
    else
        RELEASE_NOTES+=("🎯 Enhanced: $MSG")
    fi
done <<< "$COMMITS_SINCE"

if [ ${#RELEASE_NOTES[@]} -eq 0 ]; then
    RELEASE_NOTES=("🎯 Enhanced: Maintenance release")
fi

echo -e "${GREEN}✓ Generated ${#RELEASE_NOTES[@]} release note(s)${NC}\n"

# 4. Source Rust environment
echo -e "${BLUE}[4/5] 🦀 Loading Rust environment...${NC}"
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
    echo -e "${GREEN}✓ Rust loaded${NC}\n"
else
    echo -e "${YELLOW}⚠️  Rust not found - release.sh will handle installation${NC}\n"
fi

# 5. Run release script
echo -e "${BLUE}[5/5] 🚀 Running release.sh...${NC}\n"
./scripts/release.sh "$NEW_VERSION" "${RELEASE_NOTES[@]}"

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✅ Automated Release v${NEW_VERSION} Complete!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
