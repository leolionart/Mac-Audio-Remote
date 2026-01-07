#!/bin/bash

# Quick setup script for Claude Code Telegram & Raycast hooks
# This script helps configure the hooks for first-time use

set -e

echo "🚀 Claude Code Hooks Setup"
echo "=========================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "📁 Project: $(basename "$PROJECT_ROOT")"
echo "📂 Hooks location: ${SCRIPT_DIR}"
echo ""

# Step 1: Ask for Telegram Chat ID
echo "Step 1: Telegram Configuration"
echo "--------------------------------"
echo ""
echo "Your bot token is already configured."
echo ""
read -p "Do you know your Telegram Chat ID? (y/n): " knows_chat_id

if [ "$knows_chat_id" = "y" ] || [ "$knows_chat_id" = "Y" ]; then
    read -p "Enter your Telegram Chat ID: " chat_id

    if [ -n "$chat_id" ]; then
        # Update send_telegram.sh with the chat ID
        sed -i.bak "s/CHAT_ID=\"\${TELEGRAM_CHAT_ID:-.*/CHAT_ID=\"\${TELEGRAM_CHAT_ID:-${chat_id}}\"/" "${SCRIPT_DIR}/send_telegram.sh"
        echo -e "${GREEN}✓${NC} Chat ID configured in send_telegram.sh"

        # Also suggest environment variable
        echo ""
        echo "Tip: You can also set it as an environment variable:"
        echo "  export TELEGRAM_CHAT_ID=\"${chat_id}\""
        echo "  Add this to your ~/.zshrc or ~/.bashrc for persistence"
    fi
else
    echo ""
    echo "To get your Chat ID:"
    echo "1. Start a chat with your bot in Telegram"
    echo "2. Send any message to the bot"
    echo "3. Visit this URL in your browser:"
    echo "   https://api.telegram.org/bot6636081676:AAGGbQN6Epjdj2xAl5aF7cRgVhb_DDaHLF4/getUpdates"
    echo "4. Look for \"chat\":{\"id\":YOUR_CHAT_ID} in the response"
    echo ""
    echo "Then run this setup script again."
fi

echo ""

# Step 2: Test Telegram connection
echo "Step 2: Test Telegram Connection"
echo "---------------------------------"
read -p "Would you like to send a test notification? (y/n): " test_telegram

if [ "$test_telegram" = "y" ] || [ "$test_telegram" = "Y" ]; then
    "${SCRIPT_DIR}/send_telegram.sh" \
        "Setup Test 🎉" \
        "Claude Code hooks are being configured!" \
        "Project: $(basename "$PROJECT_ROOT")"
    echo ""
fi

# Step 3: Configure Claude Code
echo ""
echo "Step 3: Configure Claude Code"
echo "------------------------------"
echo ""
echo "Choose configuration method:"
echo "1. Project-specific (recommended for this project)"
echo "2. Global (applies to all Claude Code sessions)"
echo "3. Skip for now"
echo ""
read -p "Enter choice (1-3): " config_choice

case $config_choice in
    1)
        # Create .clauderc in project root
        if [ -f "${PROJECT_ROOT}/.clauderc" ]; then
            echo -e "${YELLOW}⚠${NC} .clauderc already exists"
            read -p "Overwrite? (y/n): " overwrite
            if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
                echo "Skipping .clauderc creation"
            else
                cp "${PROJECT_ROOT}/.clauderc.example" "${PROJECT_ROOT}/.clauderc"
                echo -e "${GREEN}✓${NC} Created .clauderc in project root"
            fi
        else
            cp "${PROJECT_ROOT}/.clauderc.example" "${PROJECT_ROOT}/.clauderc"
            echo -e "${GREEN}✓${NC} Created .clauderc in project root"
        fi
        ;;
    2)
        echo ""
        echo "Add this to your Claude Code settings:"
        echo ""
        echo "~/.config/claude-code/settings.json:"
        echo "{"
        echo "  \"hooks\": {"
        echo "    \"user-prompt-submit\": \"${SCRIPT_DIR}/approval_hook.sh\","
        echo "    \"task-complete\": \"${SCRIPT_DIR}/completion_hook.sh\""
        echo "  }"
        echo "}"
        echo ""
        ;;
    3)
        echo "Skipping configuration"
        ;;
esac

echo ""

# Step 4: Test hooks
echo "Step 4: Test Hooks"
echo "------------------"
read -p "Would you like to test all hooks now? (y/n): " test_hooks

if [ "$test_hooks" = "y" ] || [ "$test_hooks" = "Y" ]; then
    echo ""
    "${SCRIPT_DIR}/test_hooks.sh"
fi

echo ""
echo "=========================="
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Check your Telegram for notifications"
echo "2. Start using Claude Code - hooks will trigger automatically"
echo "3. Customize hook messages in scripts/hooks/*.sh"
echo ""
echo "Documentation: scripts/hooks/README.md"
echo "Test anytime: scripts/hooks/test_hooks.sh"
echo ""
