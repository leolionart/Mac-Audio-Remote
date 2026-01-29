#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 🚀 MicDrop Release Script                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
BUNDLE_NAME="MicDrop"

# ============================================================================
# STEP 1: Pre-flight checks
# ============================================================================
echo -e "${BLUE}[1/8] 🔍 Pre-flight checks...${NC}"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged into GitHub${NC}"
    echo "Please login first: gh auth login"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes:${NC}"
    git status --short
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✓ All checks passed${NC}"
echo ""

# ============================================================================
# STEP 2: Get current version and ask for new version
# ============================================================================
echo -e "${BLUE}[2/8] 📝 Version management...${NC}"

CURRENT_VERSION=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString)
CURRENT_BUILD=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion)

echo -e "Current version: ${YELLOW}${CURRENT_VERSION}${NC} (build ${CURRENT_BUILD})"
echo ""

if [ -n "$1" ]; then
    NEW_VERSION="$1"
    echo "Using version from argument: $NEW_VERSION"
else
    read -p "Enter new version (e.g., 2.2.0): " NEW_VERSION
fi

if [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}❌ Version cannot be empty${NC}"
    exit 1
fi

# Validate version format (semantic versioning)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid version format. Use semantic versioning (e.g., 2.2.0)${NC}"
    exit 1
fi

# Auto-increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "${GREEN}✓ New version: ${NEW_VERSION} (build ${NEW_BUILD})${NC}"
echo ""

# ============================================================================
# STEP 3: Collect release notes
# ============================================================================
echo -e "${BLUE}[3/8] 📋 Release notes...${NC}"

RELEASE_ITEMS=()

if [ -n "$2" ]; then
    echo "Using release notes from arguments..."
    # Iterate over remaining arguments starting from $2
    for note in "${@:2}"; do
        RELEASE_ITEMS+=("$note")
    done
else
    echo "Enter release notes (one per line, empty line to finish):"
    echo "Examples:"
    echo "  ✨ New: Feature description"
    echo "  🔧 Fix: Bug fix description"
    echo "  🎯 Enhanced: Improvement description"
    echo ""

    while true; do
        read -p "> " line
        if [ -z "$line" ]; then
            break
        fi
        RELEASE_ITEMS+=("$line")
    done
fi

if [ ${#RELEASE_ITEMS[@]} -eq 0 ]; then
    echo -e "${RED}❌ At least one release note is required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${#RELEASE_ITEMS[@]} release note(s) collected${NC}"
echo ""

# ============================================================================
# STEP 4: Update Info.plist
# ============================================================================
echo -e "${BLUE}[4/8] 📝 Updating Info.plist...${NC}"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "AudioRemote/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "AudioRemote/Resources/Info.plist"

echo -e "${GREEN}✓ Updated to version ${NEW_VERSION} (build ${NEW_BUILD})${NC}"
echo ""

# ============================================================================
# STEP 5: Build and test
# ============================================================================
echo -e "${BLUE}[5/8] 🔨 Building app...${NC}"

# Get script directory and run build script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/build_app_bundle.sh"

if [ ! -d ".build/release/${BUNDLE_NAME}.app" ]; then
    echo -e "${RED}❌ Build failed - app bundle not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Quick test - check if critical files exist
echo -e "${BLUE}[5/8] 🧪 Testing app bundle...${NC}"

REQUIRED_FILES=(
    ".build/release/${BUNDLE_NAME}.app/Contents/MacOS/AudioRemote"
    ".build/release/${BUNDLE_NAME}.app/Contents/Info.plist"
    ".build/release/${BUNDLE_NAME}.app/Contents/Resources/AppIcon.icns"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$file" ]; then
        echo -e "${RED}❌ Missing required file: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ All required files present${NC}"
echo ""

# ============================================================================
# STEP 6: Create DMG and ZIP
# ============================================================================
echo -e "${BLUE}[6/8] 📦 Creating artifacts...${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Create DMG
"$SCRIPT_DIR/create_dmg.sh"

cd .build/release
if [ ! -f "${BUNDLE_NAME}.dmg" ]; then
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

mv "${BUNDLE_NAME}.dmg" "${BUNDLE_NAME}-${NEW_VERSION}.dmg"
DMG_SIZE=$(stat -f%z "${BUNDLE_NAME}-${NEW_VERSION}.dmg")
DMG_SIZE_MB=$(echo "scale=2; $DMG_SIZE / 1024 / 1024" | bc)
echo -e "${GREEN}✓ Created ${BUNDLE_NAME}-${NEW_VERSION}.dmg (${DMG_SIZE_MB} MB)${NC}"

# 2. Create ZIP (for auto-update compatibility)
echo "📦 Creating ZIP archive..."
rm -f "${BUNDLE_NAME}-${NEW_VERSION}.zip"
zip -r "${BUNDLE_NAME}-${NEW_VERSION}.zip" ${BUNDLE_NAME}.app > /dev/null

ZIP_SIZE=$(stat -f%z "${BUNDLE_NAME}-${NEW_VERSION}.zip")
ZIP_SIZE_MB=$(echo "scale=2; $ZIP_SIZE / 1024 / 1024" | bc)
echo -e "${GREEN}✓ Created ${BUNDLE_NAME}-${NEW_VERSION}.zip (${ZIP_SIZE_MB} MB)${NC}"

cd ../..
echo ""

# ============================================================================
# STEP 7: Git commit, tag, and push
# ============================================================================
echo -e "${BLUE}[7/8] 📤 Git operations...${NC}"

git add AudioRemote/Resources/Info.plist
git commit -m "chore: Release v${NEW_VERSION}

$(for item in "${RELEASE_ITEMS[@]}"; do echo "- ${item}"; done)"

echo "📥 Pulling latest changes..."
git pull --rebase origin main || {
    echo -e "${RED}❌ Git pull failed. Please resolve conflicts manually.${NC}"
    exit 1
}

git push origin main

# Delete existing tag if it exists
git tag -d "v${NEW_VERSION}" 2>/dev/null || true
git push origin ":refs/tags/v${NEW_VERSION}" 2>/dev/null || true

# Create and push new tag
git tag "v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"

echo -e "${GREEN}✓ Git operations complete${NC}"
echo ""

# ============================================================================
# STEP 8: Create GitHub Release
# ============================================================================
echo -e "${BLUE}[8/8] 🚀 Creating GitHub Release...${NC}"

# Build full release notes for GitHub
GITHUB_RELEASE_NOTES="## 🔧 ${BUNDLE_NAME} v${NEW_VERSION}

### What's New
$(for item in "${RELEASE_ITEMS[@]}"; do echo "- ${item}"; done)

### Installation
1. Download \`${BUNDLE_NAME}-${NEW_VERSION}.dmg\` below
2. Open the DMG file
3. Drag **${BUNDLE_NAME}** to the **Applications** folder
4. Launch the app from Applications
5. Grant necessary permissions when prompted

### Requirements
- macOS 13.0 (Ventura) or later
- Microphone permission (for mic toggle)
- Notification permission (for audio notifications)

### iOS Shortcuts Integration
Control your Mac remotely via HTTP:
\`\`\`
POST http://YOUR_MAC_IP:8765/toggle-mic       # Toggle microphone
POST http://YOUR_MAC_IP:8765/volume/increase   # Increase volume
POST http://YOUR_MAC_IP:8765/volume/decrease   # Decrease volume
POST http://YOUR_MAC_IP:8765/volume/toggle-mute # Mute/unmute
GET  http://YOUR_MAC_IP:8765/status            # Get current status
\`\`\`

For setup guide, see [iOS Shortcuts Documentation](https://github.com/leolionart/Mac-Audio-Remote/blob/main/docs/iOS-SHORTCUTS-GUIDE.md)."

gh release create "v${NEW_VERSION}" \
  ".build/release/${BUNDLE_NAME}-${NEW_VERSION}.dmg" \
  ".build/release/${BUNDLE_NAME}-${NEW_VERSION}.zip" \
  --title "v${NEW_VERSION}" \
  --notes "$GITHUB_RELEASE_NOTES"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ Release v${NEW_VERSION} Complete!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🔗 Release URL:${NC} https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v${NEW_VERSION}"
echo -e "${BLUE}📦 Download URL:${NC} https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/${BUNDLE_NAME}-${NEW_VERSION}.dmg"
echo ""
