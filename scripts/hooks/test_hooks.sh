#!/bin/bash

# Test script for Claude Code hooks
# Tests both Raycast and Telegram notifications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Claude Code Hooks"
echo "=============================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test 1: Telegram notification script
echo "📱 Test 1: Telegram Notification Script"
echo "----------------------------------------"
if [ -f "${SCRIPT_DIR}/send_telegram.sh" ]; then
    echo -e "${GREEN}✓${NC} send_telegram.sh exists"

    # Check if executable
    if [ -x "${SCRIPT_DIR}/send_telegram.sh" ]; then
        echo -e "${GREEN}✓${NC} send_telegram.sh is executable"

        # Send test notification
        echo "Sending test Telegram notification..."
        if "${SCRIPT_DIR}/send_telegram.sh" \
            "Test Notification 🧪" \
            "This is a test message from Claude Code hooks." \
            "If you see this message, your Telegram integration is working correctly!"; then
            echo -e "${GREEN}✓${NC} Test Telegram notification sent successfully"
        else
            echo -e "${RED}✗${NC} Failed to send test Telegram notification"
        fi
    else
        echo -e "${RED}✗${NC} send_telegram.sh is not executable"
        echo "Run: chmod +x ${SCRIPT_DIR}/send_telegram.sh"
    fi
else
    echo -e "${RED}✗${NC} send_telegram.sh not found"
fi

echo ""

# Test 2: Approval hook
echo "⚠️  Test 2: Approval Hook"
echo "----------------------------------------"
if [ -f "${SCRIPT_DIR}/approval_hook.sh" ]; then
    echo -e "${GREEN}✓${NC} approval_hook.sh exists"

    if [ -x "${SCRIPT_DIR}/approval_hook.sh" ]; then
        echo -e "${GREEN}✓${NC} approval_hook.sh is executable"

        # Simulate hook trigger
        echo "Triggering approval hook..."
        echo '{"event":"test","type":"approval"}' | "${SCRIPT_DIR}/approval_hook.sh"
        echo -e "${GREEN}✓${NC} Approval hook executed successfully"
    else
        echo -e "${RED}✗${NC} approval_hook.sh is not executable"
        echo "Run: chmod +x ${SCRIPT_DIR}/approval_hook.sh"
    fi
else
    echo -e "${RED}✗${NC} approval_hook.sh not found"
fi

echo ""

# Test 3: Completion hook
echo "✅ Test 3: Completion Hook"
echo "----------------------------------------"
if [ -f "${SCRIPT_DIR}/completion_hook.sh" ]; then
    echo -e "${GREEN}✓${NC} completion_hook.sh exists"

    if [ -x "${SCRIPT_DIR}/completion_hook.sh" ]; then
        echo -e "${GREEN}✓${NC} completion_hook.sh is executable"

        # Simulate hook trigger
        echo "Triggering completion hook..."
        echo '{"event":"test","type":"completion"}' | "${SCRIPT_DIR}/completion_hook.sh"
        echo -e "${GREEN}✓${NC} Completion hook executed successfully"
    else
        echo -e "${RED}✗${NC} completion_hook.sh is not executable"
        echo "Run: chmod +x ${SCRIPT_DIR}/completion_hook.sh"
    fi
else
    echo -e "${RED}✗${NC} completion_hook.sh not found"
fi

echo ""

# Test 4: Environment check
echo "🔧 Test 4: Environment Check"
echo "----------------------------------------"

# Check for Raycast
if command -v raycast &> /dev/null; then
    echo -e "${GREEN}✓${NC} Raycast is installed"
else
    echo -e "${YELLOW}⚠${NC} Raycast not found (optional)"
fi

# Check for curl
if command -v curl &> /dev/null; then
    echo -e "${GREEN}✓${NC} curl is available"
else
    echo -e "${RED}✗${NC} curl is required for Telegram notifications"
fi

# Check bot token
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} TELEGRAM_BOT_TOKEN environment variable is set"
else
    echo -e "${YELLOW}⚠${NC} TELEGRAM_BOT_TOKEN not set (using hardcoded value)"
fi

# Check chat ID
if [ -n "$TELEGRAM_CHAT_ID" ]; then
    echo -e "${GREEN}✓${NC} TELEGRAM_CHAT_ID environment variable is set"
else
    echo -e "${YELLOW}⚠${NC} TELEGRAM_CHAT_ID not set (using hardcoded value)"
fi

echo ""

# Test 5: Sound check (macOS)
echo "🔊 Test 5: Sound Check"
echo "----------------------------------------"
if command -v afplay &> /dev/null; then
    echo -e "${GREEN}✓${NC} afplay is available (macOS)"

    # Test sounds
    if [ -f "/System/Library/Sounds/Ping.aiff" ]; then
        echo "Playing approval sound (Ping)..."
        afplay /System/Library/Sounds/Ping.aiff &
        echo -e "${GREEN}✓${NC} Approval sound available"
    fi

    sleep 1

    if [ -f "/System/Library/Sounds/Glass.aiff" ]; then
        echo "Playing completion sound (Glass)..."
        afplay /System/Library/Sounds/Glass.aiff &
        echo -e "${GREEN}✓${NC} Completion sound available"
    fi
else
    echo -e "${YELLOW}⚠${NC} afplay not found (sounds disabled)"
fi

echo ""
echo "=============================="
echo "🎉 Testing Complete!"
echo ""
echo "Next steps:"
echo "1. Check your Telegram for test messages"
echo "2. Check Raycast notifications (if installed)"
echo "3. Configure Claude Code hooks (see README.md)"
echo ""
echo "Configuration files to update:"
echo "  - ~/.config/claude-code/settings.json (global)"
echo "  - ./.clauderc (project-specific)"
echo ""
