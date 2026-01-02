#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Audio Remote Release Script${NC}"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged into GitHub${NC}"
    echo "Please login first:"
    echo "  gh auth login"
    exit 1
fi

# Get version from Info.plist
VERSION=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString)
echo -e "${BLUE}📦 Version: ${VERSION}${NC}"

# Build app
echo -e "${BLUE}🔨 Building app...${NC}"
./build_app_bundle.sh

# Create ZIP
echo -e "${BLUE}📦 Creating ZIP archive...${NC}"
cd .build/release
rm -f "AudioRemote-${VERSION}.zip"
zip -r "AudioRemote-${VERSION}.zip" AudioRemote.app
ZIP_SIZE=$(stat -f%z "AudioRemote-${VERSION}.zip")
echo -e "${GREEN}✓ Created AudioRemote-${VERSION}.zip (${ZIP_SIZE} bytes)${NC}"
cd ../..

# Update appcast.xml with file size
echo -e "${BLUE}📝 Updating appcast.xml...${NC}"
sed -i '' "s/length=\"[0-9]*\"/length=\"${ZIP_SIZE}\"/" appcast.xml

# Commit changes
echo -e "${BLUE}💾 Committing changes...${NC}"
git add AudioRemote/Resources/Info.plist build_app_bundle.sh appcast.xml
git commit -m "chore: Release v${VERSION}" || echo "No changes to commit"
git push origin main

# Create and push tag
echo -e "${BLUE}🏷️  Creating tag v${VERSION}...${NC}"
git tag -d "v${VERSION}" 2>/dev/null || true
git push origin ":refs/tags/v${VERSION}" 2>/dev/null || true
git tag "v${VERSION}"
git push origin "v${VERSION}"

# Create GitHub Release
echo -e "${BLUE}📤 Creating GitHub Release...${NC}"

RELEASE_NOTES="## 🔧 Audio Remote v${VERSION}

### Installation
1. Download \`AudioRemote-${VERSION}.zip\` below
2. Extract and move \`AudioRemote.app\` to Applications folder
3. Launch the app - it will appear in menu bar
4. Grant necessary permissions when prompted

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

gh release create "v${VERSION}" \
  ".build/release/AudioRemote-${VERSION}.zip" \
  --title "v${VERSION}" \
  --notes "$RELEASE_NOTES"

echo ""
echo -e "${GREEN}✅ Release v${VERSION} created successfully!${NC}"
echo -e "${BLUE}🔗 View at: https://github.com/leolionart/Mac-Audio-Remote/releases/tag/v${VERSION}${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Verify the release looks correct"
echo "2. Test downloading and installing the app"
echo "3. Check that Sparkle auto-update detects it"
