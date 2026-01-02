#!/bin/bash
# Generate appcast.xml for Sparkle updates
# Usage: ./scripts/generate_appcast.sh [version]

set -e

VERSION=${1:-"2.0.0"}
ZIP_FILE="releases/AudioRemote-${VERSION}.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Error: Release file not found: $ZIP_FILE"
    echo "Run ./scripts/simple_release.sh $VERSION first"
    exit 1
fi

echo "📦 Generating appcast.xml for v${VERSION}..."

# Get file info
FILE_SIZE=$(stat -f%z "$ZIP_FILE")
SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
DOWNLOAD_URL="https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${VERSION}/AudioRemote-${VERSION}.zip"

# Create appcast.xml
cat > appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Audio Remote</title>
        <link>https://github.com/leolionart/Mac-Audio-Remote</link>
        <description>Most recent updates for Audio Remote</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <description><![CDATA[
                <h2>Version ${VERSION}</h2>
                <ul>
                    <li>Global keyboard shortcut (Option+M)</li>
                    <li>Automatic in-app updates via Sparkle</li>
                    <li>HTTP webhooks for iOS Shortcuts</li>
                    <li>Volume control support</li>
                </ul>
            ]]></description>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure url="${DOWNLOAD_URL}"
                       sparkle:version="${VERSION}"
                       sparkle:shortVersionString="${VERSION}"
                       length="${FILE_SIZE}"
                       type="application/octet-stream" />
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
EOF

echo "✅ appcast.xml created!"
echo ""
echo "📄 File: appcast.xml"
echo "📦 Version: ${VERSION}"
echo "📊 Size: ${FILE_SIZE} bytes"
echo "🔐 SHA256: ${SHA256}"
echo "🔗 Download URL: ${DOWNLOAD_URL}"
echo ""
echo "📝 Next steps:"
echo "1. Commit appcast.xml to main branch"
echo "2. Users will get automatic update notifications"
echo ""
echo "⚠️  Note: EdDSA signature will be added automatically by Sparkle"
echo "   (No code signing needed - Sparkle signs the appcast, not the app)"
