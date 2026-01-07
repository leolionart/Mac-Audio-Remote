#!/bin/bash

# Claude Code Approval Hook
# Triggers when Claude needs user approval
# Sends notifications to both Raycast and Telegram

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook data from stdin
HOOK_DATA=$(cat)

# Extract information (you can customize this based on what data Claude sends)
PROJECT_NAME=$(basename "$PWD")
TIMESTAMP=$(date '+%H:%M:%S')

# Prepare messages
RAYCAST_TITLE="Claude Code: Approval Needed"
RAYCAST_MESSAGE="Project: $PROJECT_NAME - Check your terminal"

TELEGRAM_TITLE="Approval Needed ⚠️"
TELEGRAM_MESSAGE="Claude Code needs your approval to proceed.
Please return to your computer to review and approve the request."
TELEGRAM_DETAILS="Project: $PROJECT_NAME
Working Directory: $PWD
Time: $(date '+%Y-%m-%d %H:%M:%S')

Action Required: Review Claude's proposal in your terminal"

# Send Raycast notification
if command -v raycast &> /dev/null; then
    raycast confetti &> /dev/null || true
    osascript -e "display notification \"$RAYCAST_MESSAGE\" with title \"$RAYCAST_TITLE\" sound name \"Ping\"" &> /dev/null || true
fi

# Send Telegram notification
"${SCRIPT_DIR}/send_telegram.sh" "$TELEGRAM_TITLE" "$TELEGRAM_MESSAGE" "$TELEGRAM_DETAILS" &

# Optional: Play a sound (macOS)
afplay /System/Library/Sounds/Ping.aiff 2>/dev/null || true

echo "✅ Approval notifications sent to Raycast and Telegram"

exit 0
