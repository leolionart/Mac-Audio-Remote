#!/bin/bash
# Generate EdDSA key pair for Sparkle updates
# Usage: ./scripts/generate_sparkle_keys.sh

set -e

KEYS_DIR="$(pwd)/.sparkle_keys"
PRIVATE_KEY="${KEYS_DIR}/sparkle_private_key"
PUBLIC_KEY="${KEYS_DIR}/sparkle_public_key"

echo "🔑 Generating Sparkle EdDSA key pair..."

# Create keys directory
mkdir -p "${KEYS_DIR}"

# Check if Sparkle tools are available
if ! command -v generate_keys &> /dev/null; then
    echo "❌ Sparkle generate_keys tool not found!"
    echo ""
    echo "Install via Homebrew:"
    echo "  brew install sparkle"
    echo ""
    echo "OR download from:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

# Generate keys
echo "Generating keys..."
cd "${KEYS_DIR}"
generate_keys

echo ""
echo "✅ Keys generated successfully!"
echo ""
echo "📁 Private key: ${PRIVATE_KEY}"
echo "📁 Public key: ${PUBLIC_KEY}"
echo ""
echo "🔐 IMPORTANT SECURITY NOTES:"
echo ""
echo "1. NEVER commit sparkle_private_key to git!"
echo "   Add to .gitignore: echo '.sparkle_keys/' >> .gitignore"
echo ""
echo "2. Store private key securely:"
echo "   - 1Password / Keychain"
echo "   - GitHub Secrets (for CI/CD)"
echo ""
echo "3. Add public key to Info.plist:"
echo "   <key>SUPublicEDKey</key>"
echo "   <string>$(cat ${PUBLIC_KEY})</string>"
echo ""
echo "📋 Copy public key to clipboard:"
echo "   pbcopy < ${PUBLIC_KEY}"
