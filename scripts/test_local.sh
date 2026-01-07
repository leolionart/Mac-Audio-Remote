#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           🧪 Audio Remote Local Test Script                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Build and Test App Locally
# ============================================================================

echo -e "${BLUE}[1/5] 🔨 Building app...${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/build_app_bundle.sh"

if [ ! -d ".build/release/AudioRemote.app" ]; then
    echo -e "${RED}❌ Build failed - app bundle not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# ============================================================================
# Verify app bundle structure
# ============================================================================

echo -e "${BLUE}[2/5] 🧪 Verifying app bundle structure...${NC}"

REQUIRED_FILES=(
    ".build/release/AudioRemote.app/Contents/MacOS/AudioRemote"
    ".build/release/AudioRemote.app/Contents/Info.plist"
    ".build/release/AudioRemote.app/Contents/Resources/AppIcon.icns"
)

ALL_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$file" ]; then
        echo -e "${RED}  ❌ Missing: $file${NC}"
        ALL_OK=false
    else
        echo -e "${GREEN}  ✓ Found: $(basename "$file")${NC}"
    fi
done

if [ "$ALL_OK" = false ]; then
    echo -e "${RED}❌ Some required files are missing${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All required files present${NC}"
echo ""

# ============================================================================
# Check version info
# ============================================================================

echo -e "${BLUE}[3/5] 📝 Checking version info...${NC}"

VERSION=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$(pwd)/AudioRemote/Resources/Info.plist" CFBundleVersion)

echo -e "  Version: ${YELLOW}${VERSION}${NC} (build ${BUILD})"
echo -e "${GREEN}✓ Version info valid${NC}"
echo ""

# ============================================================================
# Launch app for testing
# ============================================================================

echo -e "${BLUE}[4/5] 🚀 Launching app for testing...${NC}"

# Kill any existing instance
killall AudioRemote 2>/dev/null || true
sleep 1

# Launch app
open .build/release/AudioRemote.app
sleep 3

# Check if app is running
if pgrep -x AudioRemote > /dev/null; then
    echo -e "${GREEN}✓ App is running (PID: $(pgrep AudioRemote))${NC}"
else
    echo -e "${RED}❌ App failed to launch${NC}"
    exit 1
fi
echo ""

# ============================================================================
# Test HTTP server
# ============================================================================

echo -e "${BLUE}[5/5] 🌐 Testing HTTP server...${NC}"

# Wait for server to start
sleep 2

# Test status endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8765/status || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP server is running (status: $HTTP_CODE)${NC}"

    # Get status
    STATUS=$(curl -s http://localhost:8765/status)
    echo -e "  Status: ${STATUS}"
else
    echo -e "${YELLOW}⚠️  HTTP server may not be enabled (status: $HTTP_CODE)${NC}"
    echo -e "  Note: Enable HTTP server in Settings to test webhook functionality"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ Local Test Complete                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Test Summary:${NC}"
echo -e "  • Build: ✅ Success"
echo -e "  • Bundle: ✅ All files present"
echo -e "  • Version: ${VERSION} (build ${BUILD})"
echo -e "  • Launch: ✅ App running"
echo -e "  • Server: $([ "$HTTP_CODE" = "200" ] && echo "✅ Working" || echo "⚠️  Check Settings")"
echo ""
echo -e "${YELLOW}👉 Manual Testing Checklist:${NC}"
echo "  1. Check menu bar icon appears correctly"
echo "  2. Test microphone toggle (Option+M)"
echo "  3. Open Settings and verify all sections"
echo "  4. Check version displays correctly"
echo "  5. Test volume controls"
echo "  6. Verify network indicators show server status"
echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "  • App is now running - test all features manually"
echo "  • When satisfied, press Ctrl+C and run ./release.sh"
echo "  • To stop: killall AudioRemote"
echo ""

# Keep script running to monitor app
echo -e "${YELLOW}Press Ctrl+C to stop monitoring and quit app...${NC}"
trap "killall AudioRemote 2>/dev/null; echo ''; echo -e '${GREEN}✓ Test session ended${NC}'; exit 0" INT

# Monitor app while it's running
while pgrep -x AudioRemote > /dev/null; do
    sleep 5
done

echo -e "${YELLOW}⚠️  App stopped running${NC}"
