#!/bin/bash

# Telegram notification script for Claude Code hooks
# Usage: send_telegram.sh <title> <message> [additional_info]

set -e

# Configuration
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-6636081676:AAGGbQN6Epjdj2xAl5aF7cRgVhb_DDaHLF4}"
CHAT_ID="${TELEGRAM_CHAT_ID:--1002377054206}"  # Set your chat ID here or via environment variable
API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

# Parse arguments
TITLE="$1"
MESSAGE="$2"
ADDITIONAL_INFO="${3:-}"

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get current directory (project name)
PROJECT_DIR=$(basename "$PWD")

# Build the notification message with formatting
FORMATTED_MESSAGE="🤖 *Claude Code Notification*

📋 *Project:* \`${PROJECT_DIR}\`
⏰ *Time:* ${TIMESTAMP}

🔔 *${TITLE}*
${MESSAGE}"

# Add additional info if provided
if [ -n "$ADDITIONAL_INFO" ]; then
    FORMATTED_MESSAGE="${FORMATTED_MESSAGE}

📝 *Details:*
\`\`\`
${ADDITIONAL_INFO}
\`\`\`"
fi

# Send to Telegram with markdown parsing
RESPONSE=$(curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${FORMATTED_MESSAGE}\",
        \"parse_mode\": \"Markdown\",
        \"disable_web_page_preview\": true
    }")

# Check if the message was sent successfully
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Telegram notification sent successfully"
    exit 0
else
    echo "❌ Failed to send Telegram notification"
    echo "Response: $RESPONSE"
    exit 1
fi
