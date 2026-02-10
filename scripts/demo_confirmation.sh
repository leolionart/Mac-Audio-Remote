#!/bin/bash

# Interactive demo script for MicDrop Bridge confirmation pattern
# Shows real-time event flow between iOS → Server → Extension

SERVER="http://localhost:8765"
DELAY=0.5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Unicode symbols
ARROW="→"
CHECK="✅"
CROSS="❌"
WAIT="⏳"
ROCKET="🚀"
MIC="🎤"
PHONE="📱"
COMPUTER="💻"
CHROME="🌐"

clear
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                           ║${NC}"
echo -e "${BOLD}${CYAN}║           ${MIC}  MicDrop Bridge - Live Demo  ${COMPUTER}            ║${NC}"
echo -e "${BOLD}${CYAN}║                                                           ║${NC}"
echo -e "${BOLD}${CYAN}║         Confirmation Pattern Visualization                ║${NC}"
echo -e "${BOLD}${CYAN}║                                                           ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
sleep 1

# Check server
echo -e "${YELLOW}Checking server health...${NC}"
STATUS=$(curl -s -w "%{http_code}" -o /dev/null "$SERVER/status")
if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}${CHECK} MicDrop Server is running on port 8765${NC}"
else
    echo -e "${RED}${CROSS} Server not available${NC}"
    echo "Please start: swift build && .build/debug/AudioRemote"
    exit 1
fi
echo ""
sleep $DELAY

# Demo 1: Successful Confirmation Flow
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}Demo 1: Successful Confirmation Flow${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep $DELAY

echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   Sending toggle request..."
sleep $DELAY

# Start toggle in background
(
    sleep 1
    echo ""
    echo -e "${CYAN}${CHROME} Chrome Extension:${NC}"
    echo -e "   ${ARROW} Received 'mute-mic' event from long-poll"
    sleep $DELAY
    echo -e "   ${ARROW} Clicking microphone button in Google Meet..."
    sleep $DELAY
    echo -e "   ${ARROW} Verifying actual mute state from DOM..."
    sleep $DELAY
    echo -e "   ${ARROW} Sending confirmation: ${GREEN}muted=true${NC}"

    # Send actual confirmation
    curl -s -X POST "$SERVER/bridge/mic-state" \
        -H "Content-Type: application/json" \
        -d '{"muted": true}' > /dev/null
) &
BG_PID=$!

echo ""
echo -e "${COMPUTER} MicDrop Server:${NC}"
echo -e "   ${ARROW} Broadcasting 'mute-mic' event..."
echo -e "   ${WAIT} Waiting for confirmation (timeout: 3s)..."

START=$(date +%s%3N)
RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic")
END=$(date +%s%3N)
LATENCY=$((END - START))

wait $BG_PID 2>/dev/null

echo ""
echo -e "${COMPUTER} MicDrop Server:${NC}"
echo -e "   ${CHECK} Confirmation received!"
echo -e "   ${ARROW} Returning response to iOS Shortcuts"
echo ""
echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   ${CHECK} Response: ${GREEN}$RESPONSE${NC}"
echo -e "   ${ARROW} Latency: ${YELLOW}${LATENCY}ms${NC}"
echo ""
sleep 1

# Demo 2: Timeout Scenario
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}Demo 2: Timeout Scenario (Extension Not Running)${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep $DELAY

echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   Sending toggle request..."
sleep $DELAY

echo ""
echo -e "${COMPUTER} MicDrop Server:${NC}"
echo -e "   ${ARROW} Broadcasting 'mute-mic' event..."
echo -e "   ${WAIT} Waiting for confirmation (timeout: 3s)..."

echo ""
echo -e "${RED}${CHROME} Chrome Extension:${NC}"
echo -e "   ${CROSS} Not running / crashed"
echo -e "   ${CROSS} No confirmation received"

START=$(date +%s%3N)

# Show countdown
for i in {3..1}; do
    sleep 1
    echo -e "   ${YELLOW}⏱  Timeout in ${i}s...${NC}"
done

RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic")
END=$(date +%s%3N)
LATENCY=$((END - START))

echo ""
echo -e "${COMPUTER} MicDrop Server:${NC}"
echo -e "   ${CROSS} Timeout reached (3000ms)"
echo -e "   ${ARROW} Returning timeout response"
echo ""
echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   ${YELLOW}⚠️  Response: $RESPONSE${NC}"
echo -e "   ${ARROW} Latency: ${RED}${LATENCY}ms${NC}"
echo ""
sleep 1

# Demo 3: Fast Mode (Legacy)
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}Demo 3: Fast Mode (No Confirmation)${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep $DELAY

echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   Sending to ${YELLOW}/toggle-mic/fast${NC}..."
sleep $DELAY

echo ""
echo -e "${COMPUTER} MicDrop Server:${NC}"
echo -e "   ${ARROW} Broadcasting event (no wait)..."
echo -e "   ${ROCKET} Returning immediately (optimistic)"

START=$(date +%s%3N)
RESPONSE=$(curl -s -X POST "$SERVER/toggle-mic/fast")
END=$(date +%s%3N)
LATENCY=$((END - START))

echo ""
echo -e "${MAGENTA}${PHONE} iOS Shortcuts:${NC}"
echo -e "   ${CHECK} Response: ${GREEN}$RESPONSE${NC}"
echo -e "   ${ROCKET} Latency: ${GREEN}${LATENCY}ms${NC} (100x faster!)"
echo ""
echo -e "${YELLOW}⚠️  Trade-off: No guarantee that mute actually happened${NC}"
echo ""
sleep 1

# Summary
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                        Summary                            ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}${CHECK} Confirmation Mode:${NC}"
echo -e "   • Guarantees mute happened"
echo -e "   • ~100ms latency"
echo -e "   • Timeout detection"
echo -e "   • URL: ${BOLD}/toggle-mic${NC}"
echo ""
echo -e "${YELLOW}${ROCKET} Fast Mode:${NC}"
echo -e "   • No guarantee"
echo -e "   • ~1ms latency"
echo -e "   • No timeout"
echo -e "   • URL: ${BOLD}/toggle-mic/fast${NC}"
echo ""
echo -e "${BLUE}${MIC} Next Steps:${NC}"
echo -e "   1. Install Chrome Extension"
echo -e "   2. Open Google Meet call"
echo -e "   3. Test: ${BOLD}curl -X POST $SERVER/toggle-mic${NC}"
echo ""
echo -e "${CYAN}Documentation:${NC}"
echo -e "   • Quick Start: ${BOLD}docs/QUICK_START_CONFIRMATION.md${NC}"
echo -e "   • Full Guide:  ${BOLD}docs/EXTENSION_INTEGRATION.md${NC}"
echo ""
