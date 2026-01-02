#!/bin/bash
# Simple release script without code signing
# Usage: ./scripts/simple_release.sh [version]

set -e

VERSION=${1:-"2.0.0"}
APP_NAME="AudioRemote"
RELEASE_DIR="releases"
OUTPUT_ZIP="${RELEASE_DIR}/${APP_NAME}-${VERSION}.zip"

echo "🚀 Building ${APP_NAME} v${VERSION} (unsigned)..."

# Clean and build
echo "🧹 Cleaning..."
rm -rf .build
rm -rf ${APP_NAME}.app

echo "🔨 Building..."
swift build -c release

echo "📦 Creating .app bundle..."
./build-app.sh

# Create releases directory
mkdir -p ${RELEASE_DIR}

# Create ZIP
echo "📦 Creating ZIP archive..."
ditto -c -k --keepParent ${APP_NAME}.app "${OUTPUT_ZIP}"

# Get file info
FILE_SIZE=$(stat -f%z "${OUTPUT_ZIP}")
FILE_SIZE_MB=$(echo "scale=2; ${FILE_SIZE}/1048576" | bc)
SHA256=$(shasum -a 256 "${OUTPUT_ZIP}" | awk '{print $1}')

echo ""
echo "✅ Release build complete!"
echo ""
echo "📦 Output: ${OUTPUT_ZIP}"
echo "📊 Size: ${FILE_SIZE_MB} MB (${FILE_SIZE} bytes)"
echo "🔐 SHA256: ${SHA256}"
echo ""
echo "⚠️  NOTE: This app is NOT code-signed"
echo "   Users will need to right-click → Open to bypass Gatekeeper"
echo ""
echo "📝 Next steps:"
echo "1. Test the app: open ${APP_NAME}.app"
echo "2. Create GitHub Release:"
echo "   gh release create v${VERSION} ${OUTPUT_ZIP} --title \"Version ${VERSION}\" --notes \"See CHANGELOG\""
echo ""
echo "3. Or upload manually to:"
echo "   https://github.com/leolionart/Mac-Audio-Remote/releases/new"
