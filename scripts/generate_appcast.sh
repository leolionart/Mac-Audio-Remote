#!/bin/bash
# Generate appcast.xml for Sparkle updates
# Usage: ./scripts/generate_appcast.sh

set -e

RELEASES_DIR="releases"
APPCAST_FILE="docs/appcast.xml"
PRIVATE_KEY_FILE=".sparkle_keys/sparkle_private_key"
GITHUB_USER="leolionart"
GITHUB_REPO="Mac-Audio-Remote"

echo "📝 Generating appcast.xml..."

# Check if private key exists
if [ ! -f "${PRIVATE_KEY_FILE}" ]; then
    echo "❌ Private key not found: ${PRIVATE_KEY_FILE}"
    echo "   Run: ./scripts/generate_sparkle_keys.sh"
    exit 1
fi

# Check if Sparkle tools are available
if ! command -v generate_appcast &> /dev/null; then
    echo "❌ Sparkle generate_appcast tool not found!"
    echo ""
    echo "Install via Homebrew:"
    echo "  brew install sparkle"
    exit 1
fi

# Create docs directory if not exists
mkdir -p docs

# Generate appcast
echo "Generating appcast from releases..."
generate_appcast \
    --ed-key-file "${PRIVATE_KEY_FILE}" \
    --download-url-prefix "https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/" \
    "${RELEASES_DIR}"

# Move generated appcast to docs
mv "${RELEASES_DIR}/appcast.xml" "${APPCAST_FILE}"

echo ""
echo "✅ Appcast generated: ${APPCAST_FILE}"
echo ""
echo "Next steps:"
echo "1. Commit and push:"
echo "   git add ${APPCAST_FILE}"
echo "   git commit -m 'chore: Update appcast'"
echo "   git push"
echo ""
echo "2. Enable GitHub Pages (if not already):"
echo "   Settings → Pages → Source: main → Folder: /docs"
echo ""
echo "3. Appcast URL will be:"
echo "   https://${GITHUB_USER}.github.io/${GITHUB_REPO}/appcast.xml"
