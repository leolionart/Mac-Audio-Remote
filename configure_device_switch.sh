#!/bin/bash

echo "🔧 Configuring Device Switch Mode"
echo "=================================="
echo ""

# Get BlackHole UID
BLACKHOLE_UID=$(system_profiler SPAudioDataType -json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for device in data.get('SPAudioDataType', [{}])[0].get('_items', []):
    if 'BlackHole' in device.get('_name', ''):
        print(device.get('coreaudio_device_input', [{}])[0].get('coreaudio_device_uid', ''))
        break
")

if [ -z "$BLACKHOLE_UID" ]; then
    echo "❌ BlackHole not found. Please install BlackHole first:"
    echo "   brew install blackhole-2ch"
    exit 1
fi

echo "✓ Found BlackHole UID: $BLACKHOLE_UID"
echo ""

# Get real mic UID (C270 webcam)
REAL_MIC_UID=$(system_profiler SPAudioDataType -json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for device in data.get('SPAudioDataType', [{}])[0].get('_items', []):
    name = device.get('_name', '')
    if 'C270' in name or 'Webcam' in name.lower():
        print(device.get('coreaudio_device_input', [{}])[0].get('coreaudio_device_uid', ''))
        break
")

if [ -z "$REAL_MIC_UID" ]; then
    echo "⚠️  No real microphone found, using built-in"
    REAL_MIC_UID="BuiltInMicrophoneDevice"
fi

echo "✓ Real mic UID: $REAL_MIC_UID"
echo ""

# Create settings JSON
SETTINGS_JSON=$(cat <<EOF
{
  "autoStart": false,
  "httpServerEnabled": true,
  "httpPort": 8765,
  "requestCount": 0,
  "volumeStep": 0.1,
  "muteMode": "deviceSwitch",
  "nullDeviceUID": "$BLACKHOLE_UID",
  "realMicDeviceUID": "$REAL_MIC_UID",
  "forceChannelMute": true
}
EOF
)

# Encode to base64 for UserDefaults
echo "$SETTINGS_JSON" | python3 -c "
import sys, json, base64, plistlib
settings = json.load(sys.stdin)
plist_data = plistlib.dumps(settings, fmt=plistlib.FMT_BINARY)
print(base64.b64encode(plist_data).decode())
" > /tmp/audio_settings.b64

if [ $? -ne 0 ]; then
    echo "❌ Failed to encode settings"
    exit 1
fi

# Write to UserDefaults
BASE64_DATA=$(cat /tmp/audio_settings.b64)
defaults write ~/Library/Preferences/AudioRemoteSettings.plist "app.settings.v2" -data "$BASE64_DATA"

if [ $? -eq 0 ]; then
    echo "✓ Settings saved to UserDefaults"
    echo ""
    echo "⚠️  Please restart AudioRemote.app for changes to take effect"
    echo ""
    echo "   killall AudioRemote"
    echo "   open .build/release/AudioRemote.app"
else
    echo "❌ Failed to write settings"
    exit 1
fi

rm /tmp/audio_settings.b64
