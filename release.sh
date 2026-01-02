#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 🚀 Audio Remote Release Script                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# STEP 1: Pre-flight checks
# ============================================================================
echo -e "${BLUE}[1/9] 🔍 Pre-flight checks...${NC}"

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
echo -e "${BLUE}[2/9] 📝 Version management...${NC}"

CURRENT_VERSION=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString)
CURRENT_BUILD=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion)

echo -e "Current version: ${YELLOW}${CURRENT_VERSION}${NC} (build ${CURRENT_BUILD})"
echo ""
read -p "Enter new version (e.g., 2.2.0): " NEW_VERSION

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
echo -e "${BLUE}[3/9] 📋 Release notes...${NC}"
echo "Enter release notes (one per line, empty line to finish):"
echo "Examples:"
echo "  ✨ New: Feature description"
echo "  🔧 Fix: Bug fix description"
echo "  🎯 Enhanced: Improvement description"
echo ""

RELEASE_ITEMS=()
while true; do
    read -p "> " line
    if [ -z "$line" ]; then
        break
    fi
    RELEASE_ITEMS+=("$line")
done

if [ ${#RELEASE_ITEMS[@]} -eq 0 ]; then
    echo -e "${RED}❌ At least one release note is required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${#RELEASE_ITEMS[@]} release note(s) collected${NC}"
echo ""

# ============================================================================
# STEP 4: Update Info.plist
# ============================================================================
echo -e "${BLUE}[4/9] 📝 Updating Info.plist...${NC}"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "AudioRemote/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "AudioRemote/Resources/Info.plist"

echo -e "${GREEN}✓ Updated to version ${NEW_VERSION} (build ${NEW_BUILD})${NC}"
echo ""

# ============================================================================
# STEP 5: Build and test
# ============================================================================
echo -e "${BLUE}[5/9] 🔨 Building app...${NC}"

./build_app_bundle.sh

if [ ! -d ".build/release/AudioRemote.app" ]; then
    echo -e "${RED}❌ Build failed - app bundle not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Quick test - check if critical files exist
echo -e "${BLUE}[5/9] 🧪 Testing app bundle...${NC}"

REQUIRED_FILES=(
    ".build/release/AudioRemote.app/Contents/MacOS/AudioRemote"
    ".build/release/AudioRemote.app/Contents/Info.plist"
    ".build/release/AudioRemote.app/Contents/Resources/AppIcon.icns"
    ".build/release/AudioRemote.app/Contents/Frameworks/Sparkle.framework"
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
# STEP 6: Create ZIP archive
# ============================================================================
echo -e "${BLUE}[6/9] 📦 Creating ZIP archive...${NC}"

cd .build/release
rm -f "AudioRemote-${NEW_VERSION}.zip"
zip -r "AudioRemote-${NEW_VERSION}.zip" AudioRemote.app > /dev/null
ZIP_SIZE=$(stat -f%z "AudioRemote-${NEW_VERSION}.zip")
ZIP_SIZE_MB=$(echo "scale=2; $ZIP_SIZE / 1024 / 1024" | bc)

echo -e "${GREEN}✓ Created AudioRemote-${NEW_VERSION}.zip (${ZIP_SIZE_MB} MB)${NC}"
cd ../..
echo ""

# ============================================================================
# STEP 7: Update appcast.xml
# ============================================================================
echo -e "${BLUE}[7/9] 📝 Updating appcast.xml...${NC}"

# Build release notes HTML
RELEASE_NOTES_HTML="                <h2>Version ${NEW_VERSION}</h2>
                <ul>"

for item in "${RELEASE_ITEMS[@]}"; do
    RELEASE_NOTES_HTML="${RELEASE_NOTES_HTML}
                    <li>${item}</li>"
done

RELEASE_NOTES_HTML="${RELEASE_NOTES_HTML}
                </ul>"

# Get current date in RFC 822 format
PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

# Create new item entry
NEW_ITEM="    <item>
        <title>Version ${NEW_VERSION}</title>
        <description><![CDATA[
${RELEASE_NOTES_HTML}
        ]]></description>
        <pubDate>${PUBDATE}</pubDate>
        <enclosure url=\"https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/AudioRemote-${NEW_VERSION}.zip\"
                   sparkle:version=\"${NEW_VERSION}\"
                   sparkle:shortVersionString=\"${NEW_VERSION}\"
                   length=\"${ZIP_SIZE}\"
                   type=\"application/octet-stream\" />
        <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    </item>"

# Write new item to temporary file
echo "$NEW_ITEM" > /tmp/new_appcast_item.xml

# Insert new item after <language>en</language> line using awk
awk '
/<language>en<\/language>/ {
    print
    while ((getline line < "/tmp/new_appcast_item.xml") > 0) {
        print line
    }
    close("/tmp/new_appcast_item.xml")
    next
}
{print}
' appcast.xml > appcast.xml.tmp && mv appcast.xml.tmp appcast.xml

rm -f /tmp/new_appcast_item.xml

echo -e "${GREEN}✓ Updated appcast.xml${NC}"
echo ""

# ============================================================================
# STEP 8: Git commit, tag, and push
# ============================================================================
echo -e "${BLUE}[8/9] 📤 Git operations...${NC}"

git add AudioRemote/Resources/Info.plist appcast.xml
git commit -m "chore: Release v${NEW_VERSION}

$(for item in "${RELEASE_ITEMS[@]}"; do echo "- ${item}"; done)"

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
# STEP 9: Create GitHub Release
# ============================================================================
echo -e "${BLUE}[9/9] 🚀 Creating GitHub Release...${NC}"

# Build full release notes for GitHub
GITHUB_RELEASE_NOTES="## 🔧 Audio Remote v${NEW_VERSION}

### What's New
$(for item in "${RELEASE_ITEMS[@]}"; do echo "- ${item}"; done)

### Installation
1. Download \`AudioRemote-${NEW_VERSION}.zip\` below
2. Extract and move \`AudioRemote.app\` to Applications folder
3. Launch the app - it will appear in menu bar
4. Grant necessary permissions when prompted

### Auto-Update
If you already have Audio Remote installed, the app will automatically notify you of this update via Sparkle.

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

For setup guide, see [iOS Shortcuts Documentation](https://github.com/leolionart/Mac-Audio-Remote/blob/main/docs/iOS-Shortcuts-Guide.md)."

gh release create "v${NEW_VERSION}" \
  ".build/release/AudioRemote-${NEW_VERSION}.zip" \
  --title "v${NEW_VERSION}" \
  --notes "$GITHUB_RELEASE_NOTES"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ Release v${NEW_VERSION} Complete!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🔗 Release URL:${NC} https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v${NEW_VERSION}"
echo -e "${BLUE}📦 Download URL:${NC} https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${NEW_VERSION}/AudioRemote-${NEW_VERSION}.zip"
echo -e "${BLUE}🔄 Appcast URL:${NC} https://raw.githubusercontent.com/leolionart/Mac-Audio-Remote/main/appcast.xml"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Verify the release looks correct on GitHub"
echo "2. Test downloading and installing the app"
echo "3. Launch existing app and verify Sparkle auto-update detects it"
echo "4. Check appcast.xml is accessible via the URL above"
echo ""
