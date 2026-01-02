#!/bin/bash
# Notarize app with Apple
# Usage: ./scripts/notarize.sh [path-to-zip]

set -e

ZIP_FILE=${1:-"releases/AudioRemote-2.0.0.zip"}

if [ ! -f "${ZIP_FILE}" ]; then
    echo "❌ ZIP file not found: ${ZIP_FILE}"
    exit 1
fi

echo "📤 Notarizing ${ZIP_FILE} with Apple..."

# Check for required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
    echo ""
    echo "⚠️  Required environment variables not set:"
    echo ""
    echo "export APPLE_ID='your@email.com'"
    echo "export APPLE_APP_PASSWORD='app-specific-password'"
    echo "export APPLE_TEAM_ID='TEAM_ID'"
    echo ""
    echo "Get app-specific password from:"
    echo "https://appleid.apple.com/account/manage → App-Specific Passwords"
    echo ""
    echo "Find Team ID at:"
    echo "https://developer.apple.com/account → Membership"
    exit 1
fi

# Submit for notarization
echo "Submitting to Apple..."
xcrun notarytool submit "${ZIP_FILE}" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Notarization successful!"
    echo ""

    # Extract and staple
    APP_NAME=$(basename "${ZIP_FILE}" .zip)
    TEMP_DIR=$(mktemp -d)

    echo "Extracting and stapling..."
    unzip -q "${ZIP_FILE}" -d "${TEMP_DIR}"
    xcrun stapler staple "${TEMP_DIR}/${APP_NAME}.app"

    # Re-zip with stapled app
    cd "${TEMP_DIR}"
    ditto -c -k --keepParent "${APP_NAME}.app" "../${ZIP_FILE}"
    cd -

    rm -rf "${TEMP_DIR}"

    echo "✅ Stapling complete!"
else
    echo "❌ Notarization failed"
    exit 1
fi
