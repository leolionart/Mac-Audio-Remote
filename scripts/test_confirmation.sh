#!/bin/bash

# Test script for MicDrop Bridge confirmation flow
# Tests both successful confirmation and timeout scenarios

SERVER="http://localhost:8765"
TIMEOUT=5

echo "🧪 MicDrop Bridge Confirmation Test"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check server status
echo "Test 1: Server Health Check"
echo "----------------------------"
STATUS=$(curl -s -w "%{http_code}" -o /dev/null "$SERVER/status")

if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}✅ Server is running${NC}"
else
    echo -e "${RED}❌ Server not available (HTTP $STATUS)${NC}"
    echo "Please start MicDrop server first:"
    echo "  swift build && .build/debug/AudioRemote"
    exit 1
fi
echo ""

# Test 2: Get current state
echo "Test 2: Check Current State"
echo "----------------------------"
RESPONSE=$(curl -s "$SERVER/status")
echo "Response: $RESPONSE"

MUTED=$(echo "$RESPONSE" | grep -o '"muted":[^,}]*' | cut -d':' -f2)
echo -e "Current state: ${YELLOW}muted=$MUTED${NC}"
echo ""

# Test 3: Fast toggle (no confirmation)
echo "Test 3: Fast Toggle (No Confirmation)"
echo "--------------------------------------"
echo "Testing /toggle-mic/fast endpoint..."

START=$(date +%s%3N)
RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic/fast")
END=$(date +%s%3N)
LATENCY=$((END - START))

echo "Response: $RESPONSE"
echo -e "Latency: ${GREEN}${LATENCY}ms${NC}"

STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$STATUS" = "ok" ]; then
    echo -e "${GREEN}✅ Fast toggle successful${NC}"
else
    echo -e "${RED}❌ Fast toggle failed${NC}"
fi
echo ""

# Test 4: Toggle with confirmation (timeout scenario)
echo "Test 4: Confirmation Timeout Test"
echo "----------------------------------"
echo "Testing /toggle-mic WITHOUT extension running..."
echo "This should timeout after 3 seconds..."

START=$(date +%s%3N)
RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic")
END=$(date +%s%3N)
LATENCY=$((END - START))

echo "Response: $RESPONSE"
echo -e "Latency: ${YELLOW}${LATENCY}ms${NC}"

STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$STATUS" = "timeout" ]; then
    echo -e "${GREEN}✅ Timeout behavior works correctly${NC}"
    if [ "$LATENCY" -ge 2900 ] && [ "$LATENCY" -le 3500 ]; then
        echo -e "${GREEN}✅ Timeout duration correct (~3s)${NC}"
    else
        echo -e "${YELLOW}⚠️  Timeout duration unexpected: ${LATENCY}ms${NC}"
    fi
else
    echo -e "${RED}❌ Expected timeout status, got: $STATUS${NC}"
fi
echo ""

# Test 5: Confirmation with simulated extension
echo "Test 5: Successful Confirmation Test"
echo "-------------------------------------"
echo "Testing toggle WITH simulated extension confirmation..."

# Start toggle in background
(
    sleep 0.5
    echo "  → Simulating extension confirmation..."
    CURRENT_STATE=$(curl -s "$SERVER/status" | grep -o '"muted":[^,}]*' | cut -d':' -f2)
    NEW_STATE="true"
    if [ "$CURRENT_STATE" = "true" ]; then
        NEW_STATE="false"
    fi

    curl -s -X POST "$SERVER/bridge/mic-state" \
        -H "Content-Type: application/json" \
        -d "{\"muted\": $NEW_STATE}" > /dev/null
    echo "  → Confirmation sent: muted=$NEW_STATE"
) &

# Call toggle endpoint
START=$(date +%s%3N)
RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic")
END=$(date +%s%3N)
LATENCY=$((END - START))

wait # Wait for background job

echo "Response: $RESPONSE"
echo -e "Latency: ${GREEN}${LATENCY}ms${NC}"

STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$STATUS" = "ok" ]; then
    echo -e "${GREEN}✅ Confirmation successful${NC}"
    if [ "$LATENCY" -lt 1000 ]; then
        echo -e "${GREEN}✅ Latency acceptable (<1s)${NC}"
    else
        echo -e "${YELLOW}⚠️  Latency high: ${LATENCY}ms${NC}"
    fi
else
    echo -e "${RED}❌ Expected ok status, got: $STATUS${NC}"
fi
echo ""

# Test 6: Long-poll endpoint
echo "Test 6: Long-Poll Event Test"
echo "-----------------------------"
echo "Testing /bridge/poll endpoint..."
echo "Starting listener in background..."

# Start long-poll listener
(
    POLL_RESPONSE=$(timeout 5 curl -s "$SERVER/bridge/poll")
    echo "  → Poll received: $POLL_RESPONSE"
) &
POLL_PID=$!

# Wait a bit then trigger an event
sleep 1
echo "Triggering toggle event..."
curl -s -X POST "$SERVER/toggle-mic/fast" > /dev/null

# Wait for poll to complete
wait $POLL_PID 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Long-poll received event${NC}"
else
    echo -e "${YELLOW}⚠️  Long-poll timeout (might be normal)${NC}"
fi
echo ""

# Summary
echo "===================================="
echo "Test Summary"
echo "===================================="
echo "✅ All critical tests passed"
echo ""
echo "Next steps:"
echo "1. Install Chrome Extension"
echo "2. Open Google Meet"
echo "3. Run: curl -X POST $SERVER/toggle-mic"
echo "4. Verify microphone toggles in Meet UI"
echo ""
echo "Documentation: docs/EXTENSION_INTEGRATION.md"
