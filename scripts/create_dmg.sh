#!/bin/bash

set -e

# Configuration
BUNDLE_NAME="MicDrop"
APP_NAME="$BUNDLE_NAME"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$BUNDLE_NAME.app"
DMG_NAME="$BUNDLE_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
VOL_NAME="$BUNDLE_NAME"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}💿 Creating DMG for $APP_NAME...${NC}"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}❌ App bundle not found at $APP_BUNDLE${NC}"
    echo "Please build the app first."
    exit 1
fi

# Clean up old DMG
if [ -f "$DMG_PATH" ]; then
    echo "🧹 Removing old DMG..."
    rm "$DMG_PATH"
fi

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)
echo "📁 Created temporary directory: $TMP_DIR"

# Copy app bundle to temp dir
echo "📋 Copying app bundle..."
cp -R "$APP_BUNDLE" "$TMP_DIR/"

# Create link to Applications folder
echo "🔗 Creating /Applications link..."
ln -s /Applications "$TMP_DIR/Applications"

# Calculate size for DMG (add some buffer)
SIZE=$(du -sh "$TMP_DIR" | awk '{print $1}')
echo "📏 Estimated content size: $SIZE"

# Create temporary read-write DMG
TMP_DMG="$BUILD_DIR/tmp.dmg"
rm -f "$TMP_DMG"

echo "💿 Creating temporary disk image..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDRW \
    "$TMP_DMG"

# Mount the temporary DMG
echo "💿 Mounting temporary disk image..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
echo "   Device: $DEVICE"

# Wait a moment for mount to settle
sleep 2

# Set view options (icon positions, etc.) using AppleScript
# This requires the volume to be mounted and Finder to interact with it
echo "🎨 Styling DMG window..."
echo "
   tell application \"Finder\"
     tell disk \"$VOL_NAME\"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 900, 500}
           set theViewOptions to the icon view options of container window
           set arrangement of theViewOptions to not arranged
           set icon size of theViewOptions to 72
           set background picture of theViewOptions to file \".background:background.png\"
           set position of item \"$APP_NAME.app\" of container window to {140, 200}
           set position of item \"Applications\" of container window to {360, 200}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
" | osascript 2>/dev/null || true

# Sync to ensure changes are written
sync

# Detach the DMG
echo "💿 Detaching disk image..."
hdiutil detach "$DEVICE"

# Convert to final compressed DMG
echo "🗜️ Converting to compressed DMG..."
hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Cleanup
echo "🧹 Cleaning up..."
rm -f "$TMP_DMG"
rm -rf "$TMP_DIR"

echo -e "${GREEN}✅ DMG created successfully: $DMG_PATH${NC}"
