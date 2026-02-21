#!/bin/bash

set -e

echo "🔨 Building AudioRemote.app bundle..."

# Configuration
APP_NAME="AudioRemote"
BUNDLE_NAME="MicDrop"
VERSION="3.0.0"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$BUNDLE_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

# Clean up old bundle
echo "🧹 Cleaning old bundle..."
rm -rf "$APP_BUNDLE"

# Build Rust FFI library
echo "🦀 Building Rust FFI library..."
if [ -f "AudioRemote/RustFFI/build.sh" ]; then
    ./AudioRemote/RustFFI/build.sh
else
    echo "⚠️  Rust FFI build script not found, skipping..."
fi

# Build release binary
echo "🔧 Building release binary..."
swift build -c release

# Create bundle structure
echo "📦 Creating app bundle structure..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$FRAMEWORKS"

# Copy binary
echo "📋 Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp "AudioRemote/Resources/Info.plist" "$CONTENTS/"

# Copy icon if exists
if [ -d "AudioRemote/Resources/Assets.xcassets" ]; then
    echo "🎨 Copying icon assets..."
    cp -R "AudioRemote/Resources/Assets.xcassets" "$RESOURCES/"
fi

# Copy Resources bundle if it exists
if [ -d "$BUILD_DIR/AudioRemote_AudioRemote.bundle" ]; then
    echo "📦 Copying resource bundle..."
    cp -R "$BUILD_DIR/AudioRemote_AudioRemote.bundle" "$RESOURCES/"

    # Copy AppIcon.icns to Resources root for Finder icon
    if [ -f "$BUILD_DIR/AudioRemote_AudioRemote.bundle/Resources/AppIcon.icns" ]; then
        echo "🎨 Copying AppIcon.icns to Resources..."
        cp "$BUILD_DIR/AudioRemote_AudioRemote.bundle/Resources/AppIcon.icns" "$RESOURCES/"
    fi
fi

# Set executable permission
chmod +x "$MACOS/$APP_NAME"

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"

# Fix rpath for frameworks
echo "🔧 Fixing framework rpaths..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/$APP_NAME" 2>/dev/null || true

# Ad-hoc sign the app bundle to avoid Gatekeeper blocking
echo "🔏 Ad-hoc signing app bundle..."
# Resolve real path (.build/release is a symlink; xattr operations need real paths)
REAL_APP_BUNDLE=$(readlink -f "$APP_BUNDLE" 2>/dev/null || echo "$APP_BUNDLE")
# Remove AppleDouble resource fork files (._*) that cause codesign to fail
find "$REAL_APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
# Remove com.apple.FinderInfo using -depth (bottom-up) so macOS doesn't re-add it
# to the bundle root directory when inner files are processed
find "$REAL_APP_BUNDLE" -depth -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build complete!"
echo "📂 App bundle: $APP_BUNDLE"
echo ""
echo "🚀 To run: open $APP_BUNDLE"
echo "📦 To create distributable: cd $BUILD_DIR && zip -r $BUNDLE_NAME-$VERSION.zip $BUNDLE_NAME.app"
