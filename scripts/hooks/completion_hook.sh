#!/bin/bash

# Claude Code Completion Hook
# Triggers when Claude completes a task
# Sends notifications to both Raycast and Telegram

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook data from stdin
HOOK_DATA=$(cat)

# Extract information
PROJECT_NAME=$(basename "$PWD")
TIMESTAMP=$(date '+%H:%M:%S')

# Prepare messages
RAYCAST_TITLE="Claude Code: Task Completed ✅"
RAYCAST_MESSAGE="Project: $PROJECT_NAME - Task finished at $TIMESTAMP"

TELEGRAM_TITLE="Task Completed ✅"
TELEGRAM_MESSAGE="Claude Code has successfully completed your task.
You can review the results when you return to your computer."
TELEGRAM_DETAILS="Project: $PROJECT_NAME
Working Directory: $PWD
Completed At: $(date '+%Y-%m-%d %H:%M:%S')

Status: Task execution finished successfully"

# Send Raycast notification
if command -v raycast &> /dev/null; then
    raycast confetti &> /dev/null || true
    osascript -e "display notification \"$RAYCAST_MESSAGE\" with title \"$RAYCAST_TITLE\" sound name \"Glass\"" &> /dev/null || true
fi

# Send Telegram notification
"${SCRIPT_DIR}/send_telegram.sh" "$TELEGRAM_TITLE" "$TELEGRAM_MESSAGE" "$TELEGRAM_DETAILS" &

# Optional: Play a sound (macOS) - different sound for completion
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true

echo "✅ Completion notifications sent to Raycast and Telegram"

exit 0
