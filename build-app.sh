#!/bin/bash

# Build script for AudioRemote.app
set -e

echo "Building AudioRemote..."
swift build -c release

echo "Creating .app bundle..."
rm -rf AudioRemote.app
mkdir -p AudioRemote.app/Contents/MacOS
mkdir -p AudioRemote.app/Contents/Resources
mkdir -p AudioRemote.app/Contents/Frameworks

echo "Copying executable..."
cp .build/release/AudioRemote AudioRemote.app/Contents/MacOS/
chmod +x AudioRemote.app/Contents/MacOS/AudioRemote

echo "Copying frameworks..."
# Copy Sparkle framework
if [ -d ".build/arm64-apple-macosx/release/Sparkle.framework" ]; then
    cp -R .build/arm64-apple-macosx/release/Sparkle.framework AudioRemote.app/Contents/Frameworks/
    echo "✓ Sparkle framework copied"
else
    echo "⚠️  Warning: Sparkle framework not found"
fi

echo "Copying resources..."
cp AudioRemote/Resources/AppIcon.icns AudioRemote.app/Contents/Resources/
cp -r AudioRemote/Resources/* AudioRemote.app/Contents/Resources/
cp AudioRemote/Resources/Info.plist AudioRemote.app/Contents/

echo "✅ AudioRemote.app created successfully!"
echo "You can now open it with: open AudioRemote.app"
