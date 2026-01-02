#!/bin/bash
# Build release version of AudioRemote
# Usage: ./scripts/build_release.sh [version]

set -e

VERSION=${1:-"2.0.0"}
APP_NAME="AudioRemote"
BUILD_DIR=".build/release"
RELEASE_DIR="releases"
OUTPUT_ZIP="${RELEASE_DIR}/${APP_NAME}-${VERSION}.zip"

echo "🚀 Building ${APP_NAME} v${VERSION} for release..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build
rm -rf ${APP_NAME}.app

# Build release
echo "🔨 Building with Swift..."
swift build -c release

# Create .app bundle
echo "📦 Creating .app bundle..."
./build-app.sh

# Update version in Info.plist (optional, should be done manually before)
# /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" ${APP_NAME}.app/Contents/Info.plist

# Code signing (if certificate available)
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "🔐 Code signing app..."
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')

    codesign --deep --force --verify --verbose \
        --sign "${IDENTITY}" \
        --options runtime \
        --timestamp \
        ${APP_NAME}.app

    echo "✅ Code signing successful"

    # Verify
    codesign --verify --deep --strict --verbose=2 ${APP_NAME}.app
else
    echo "⚠️  No Developer ID certificate found - app will NOT be signed"
    echo "   Users will need to right-click → Open to bypass Gatekeeper"
fi

# Create releases directory
mkdir -p ${RELEASE_DIR}

# Create ZIP
echo "📦 Creating ZIP archive..."
ditto -c -k --keepParent ${APP_NAME}.app "${OUTPUT_ZIP}"

# Get file size
FILE_SIZE=$(stat -f%z "${OUTPUT_ZIP}")
echo "📊 File size: ${FILE_SIZE} bytes"

# Calculate SHA256
SHA256=$(shasum -a 256 "${OUTPUT_ZIP}" | awk '{print $1}')
echo "🔐 SHA256: ${SHA256}"

echo ""
echo "✅ Release build complete!"
echo ""
echo "📦 Output: ${OUTPUT_ZIP}"
echo "📊 Size: ${FILE_SIZE} bytes"
echo "🔐 SHA256: ${SHA256}"
echo ""

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "Next steps:"
    echo "1. Notarize: ./scripts/notarize.sh ${OUTPUT_ZIP}"
    echo "2. Create GitHub Release"
    echo "3. Update appcast.xml"
else
    echo "⚠️  To enable code signing:"
    echo "1. Enroll in Apple Developer Program (\$99/year)"
    echo "2. Create Developer ID Application certificate in Xcode"
    echo "3. Re-run this script"
fi
