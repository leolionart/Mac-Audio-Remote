#!/bin/bash

# Real-time event monitor for MicDrop Bridge
# Shows live events flowing through the system

SERVER="http://localhost:8765"
LOG_FILE="/tmp/micdrop-events.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Cleanup
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping monitor...${NC}"
    kill $POLL_PID 2>/dev/null
    kill $STATUS_PID 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM

clear
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          🎤 MicDrop Bridge - Event Monitor 💻            ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check server
echo -e "${YELLOW}Checking server connection...${NC}"
STATUS=$(curl -s -w "%{http_code}" -o /dev/null "$SERVER/status")
if [ "$STATUS" -ne 200 ]; then
    echo -e "${RED}❌ Server not available${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Connected to MicDrop Server${NC}"
echo ""

# Initialize log
> "$LOG_FILE"

# Function to format timestamp
timestamp() {
    date +"%H:%M:%S.%3N"
}

# Monitor status changes
monitor_status() {
    local last_muted=""
    while true; do
        RESPONSE=$(curl -s "$SERVER/status" 2>/dev/null)
        if [ $? -eq 0 ]; then
            MUTED=$(echo "$RESPONSE" | grep -o '"muted":[^,}]*' | cut -d':' -f2)

            if [ "$MUTED" != "$last_muted" ] && [ -n "$last_muted" ]; then
                TIME=$(timestamp)
                if [ "$MUTED" = "true" ]; then
                    echo -e "${RED}[$TIME] 🔇 State Changed: MUTED${NC}"
                    echo "[$TIME] State Changed: MUTED" >> "$LOG_FILE"
                else
                    echo -e "${GREEN}[$TIME] 🎤 State Changed: UNMUTED${NC}"
                    echo "[$TIME] State Changed: UNMUTED" >> "$LOG_FILE"
                fi
            fi

            last_muted="$MUTED"
        fi
        sleep 0.5
    done
}

# Monitor long-poll events
monitor_events() {
    while true; do
        TIME=$(timestamp)
        echo -e "${BLUE}[$TIME] 📡 Listening for events...${NC}"

        RESPONSE=$(timeout 30 curl -s "$SERVER/bridge/poll" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
            EVENT=$(echo "$RESPONSE" | grep -o '"event":"[^"]*"' | cut -d'"' -f4)
            TIME=$(timestamp)

            case "$EVENT" in
                "mute-mic")
                    echo -e "${MAGENTA}[$TIME] 📢 Event Broadcast: MUTE-MIC${NC}"
                    echo "[$TIME] Event: MUTE-MIC" >> "$LOG_FILE"
                    ;;
                "unmute-mic")
                    echo -e "${MAGENTA}[$TIME] 📢 Event Broadcast: UNMUTE-MIC${NC}"
                    echo "[$TIME] Event: UNMUTE-MIC" >> "$LOG_FILE"
                    ;;
                "toggle-mic")
                    echo -e "${MAGENTA}[$TIME] 📢 Event Broadcast: TOGGLE-MIC${NC}"
                    echo "[$TIME] Event: TOGGLE-MIC" >> "$LOG_FILE"
                    ;;
                "volume-up")
                    echo -e "${CYAN}[$TIME] 🔊 Event Broadcast: VOLUME-UP${NC}"
                    echo "[$TIME] Event: VOLUME-UP" >> "$LOG_FILE"
                    ;;
                "volume-down")
                    echo -e "${CYAN}[$TIME] 🔉 Event Broadcast: VOLUME-DOWN${NC}"
                    echo "[$TIME] Event: VOLUME-DOWN" >> "$LOG_FILE"
                    ;;
                *)
                    echo -e "${YELLOW}[$TIME] ⚠️  Unknown Event: $EVENT${NC}"
                    echo "[$TIME] Event: $EVENT" >> "$LOG_FILE"
                    ;;
            esac
        elif [ $? -eq 124 ]; then
            # Timeout - normal for long-poll
            TIME=$(timestamp)
            echo -e "${BLUE}[$TIME] ⏱️  Long-poll timeout (reconnecting...)${NC}"
        fi

        sleep 0.1
    done
}

# Show instructions
echo -e "${BOLD}Monitor Active - Watching for events${NC}"
echo ""
echo -e "${CYAN}Test Commands:${NC}"
echo -e "  ${BOLD}Terminal 2:${NC} curl -X POST $SERVER/toggle-mic"
echo -e "  ${BOLD}Terminal 2:${NC} curl -X POST $SERVER/volume/increase"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━ Live Events ━━━━━━━━━━━━━━━━${NC}"
echo ""

# Start monitors in background
monitor_status &
STATUS_PID=$!

monitor_events &
POLL_PID=$!

# Wait
wait
