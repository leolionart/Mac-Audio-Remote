#!/bin/bash

echo "🧪 Active Monitoring Test Script"
echo "================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if app is running
if ! curl -s http://localhost:8765/status > /dev/null 2>&1; then
    echo -e "${RED}❌ App not running. Please start AudioRemote.app first${NC}"
    exit 1
fi

echo "✓ App is running"
echo ""

# Get current status
STATUS=$(curl -s http://localhost:8765/status)
CURRENT_DEVICE=$(echo "$STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin)['currentInputDevice'])")
MUTED=$(echo "$STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin)['muted'])")
MUTE_MODE=$(echo "$STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin)['muteMode'])")

echo "📊 Current Status:"
echo "  - Device: $CURRENT_DEVICE"
echo "  - Muted: $MUTED"
echo "  - Mode: $MUTE_MODE"
echo ""

# Warning if not in deviceSwitch mode
if [ "$MUTE_MODE" != "deviceSwitch" ]; then
    echo -e "${YELLOW}⚠️  Warning: Current mode is '$MUTE_MODE', not 'deviceSwitch'${NC}"
    echo "   Active monitoring only works in deviceSwitch mode!"
    echo ""
    echo "   To enable deviceSwitch mode:"
    echo "   1. Open app menu bar icon"
    echo "   2. Click 'Settings'"
    echo "   3. Under 'Mute Mode', select 'Device Switch'"
    echo "   4. Configure BlackHole as null device"
    echo ""
    exit 1
fi

# Check if muted
if [ "$MUTED" != "true" ]; then
    echo "🔇 Muting microphone..."
    TOGGLE_RESULT=$(curl -s -X POST http://localhost:8765/toggle-mic)
    NEW_MUTED=$(echo "$TOGGLE_RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['muted'])")

    if [ "$NEW_MUTED" = "true" ]; then
        echo -e "${GREEN}✓ Muted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to mute${NC}"
        exit 1
    fi
    sleep 1
fi

echo ""
echo "🔍 Active Monitoring Started!"
echo ""
echo -e "${YELLOW}📋 TEST STEPS:${NC}"
echo "  1. Open 'System Preferences' → 'Sound' → 'Input'"
echo "  2. Select a different input device (e.g., 'C270 HD WEBCAM')"
echo "  3. Watch this terminal for monitoring detection"
echo "  4. App should auto-switch back to BlackHole within 100ms"
echo ""
echo -e "${YELLOW}Expected Console Logs:${NC}"
echo "  ⚠️  Device switched detected! Forcing back to null device"
echo "  🔧 Force restoring mute state..."
echo ""
echo "Monitoring for 30 seconds... (Press Ctrl+C to stop)"
echo ""

# Monitor status every 500ms for 30 seconds
for i in {1..60}; do
    CURRENT_STATUS=$(curl -s http://localhost:8765/status)
    DEVICE=$(echo "$CURRENT_STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin)['currentInputDevice'])")

    if [ "$DEVICE" != "$CURRENT_DEVICE" ]; then
        echo -e "${RED}⚠️  [$(date +%T)] Device changed: $CURRENT_DEVICE → $DEVICE${NC}"

        # Wait 200ms for monitoring to kick in
        sleep 0.2

        # Check again
        NEW_STATUS=$(curl -s http://localhost:8765/status)
        RESTORED_DEVICE=$(echo "$NEW_STATUS" | python3 -c "import sys, json; print(json.load(sys.stdin)['currentInputDevice'])")

        if [ "$RESTORED_DEVICE" = "$CURRENT_DEVICE" ]; then
            echo -e "${GREEN}✅ [$(date +%T)] Auto-switched back to: $RESTORED_DEVICE${NC}"
            echo ""
            echo "🎉 Active Monitoring Test: PASSED!"
            exit 0
        else
            echo -e "${RED}❌ [$(date +%T)] Failed to auto-switch. Still on: $RESTORED_DEVICE${NC}"
            exit 1
        fi
    fi

    # Show progress dot every 2 seconds
    if [ $((i % 4)) -eq 0 ]; then
        echo -n "."
    fi

    sleep 0.5
done

echo ""
echo ""
echo -e "${YELLOW}⏰ Timeout: No device switch detected in 30 seconds${NC}"
echo "   This is normal if you didn't change the device manually"
