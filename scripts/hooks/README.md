# Claude Code Hooks - Raycast & Telegram Integration

This directory contains hook scripts for Claude Code that send notifications to both Raycast and Telegram when Claude needs approval or completes tasks.

## Files

- `send_telegram.sh` - Core Telegram notification sender
- `approval_hook.sh` - Hook for when Claude needs user approval
- `completion_hook.sh` - Hook for when Claude completes a task
- `test_hooks.sh` - Test script to verify notifications work

## Configuration

### 1. Telegram Bot Setup

The bot token is already configured in `send_telegram.sh`:
```bash
BOT_TOKEN="6636081676:AAGGbQN6Epjdj2xAl5aF7cRgVhb_DDaHLF4"
```

### 2. Set Your Telegram Chat ID

You need to set your Telegram Chat ID. There are two ways:

**Option A: Environment Variable (Recommended)**
```bash
export TELEGRAM_CHAT_ID="your_chat_id"
```

**Option B: Edit send_telegram.sh**
Open `send_telegram.sh` and replace `-1002377054206` with your actual chat ID.

#### How to get your Chat ID:
1. Start a chat with your bot
2. Send any message to the bot
3. Visit: `https://api.telegram.org/bot6636081676:AAGGbQN6Epjdj2xAl5aF7cRgVhb_DDaHLF4/getUpdates`
4. Look for `"chat":{"id":...}` in the response

### 3. Configure Claude Code Hooks

Add these hooks to your Claude Code settings:

**For global configuration** (add to `~/.config/claude-code/settings.json` or Claude Desktop config):
```json
{
  "hooks": {
    "user-prompt-submit": "absolute/path/to/scripts/hooks/approval_hook.sh",
    "task-complete": "absolute/path/to/scripts/hooks/completion_hook.sh"
  }
}
```

**For project-specific configuration** (create `.clauderc` in project root):
```json
{
  "hooks": {
    "user-prompt-submit": "./scripts/hooks/approval_hook.sh",
    "task-complete": "./scripts/hooks/completion_hook.sh"
  }
}
```

### 4. Verify Setup

Run the test script:
```bash
./scripts/hooks/test_hooks.sh
```

## Hook Events

- **user-prompt-submit**: Triggers when Claude needs your approval to proceed
- **task-complete**: Triggers when Claude completes a task

## Notification Details

### Approval Notification
- 🔔 **Title**: "Approval Needed ⚠️"
- 📱 **Channels**: Raycast + Telegram
- 🔊 **Sound**: Ping
- 📝 **Info**: Project name, working directory, timestamp

### Completion Notification
- ✅ **Title**: "Task Completed ✅"
- 📱 **Channels**: Raycast + Telegram
- 🔊 **Sound**: Glass
- 📝 **Info**: Project name, completion time, status

## Customization

### Change Telegram Message Format
Edit the `FORMATTED_MESSAGE` variable in `send_telegram.sh`

### Change Notification Sounds
Edit the `afplay` lines in the hook scripts:
- Available system sounds: `/System/Library/Sounds/`
- Common sounds: Ping, Glass, Hero, Submarine, Tink

### Disable Raycast Notifications
Comment out the Raycast notification section in the hook scripts

### Add More Information
The hooks receive data from Claude via stdin. You can parse this data and include it in notifications:
```bash
HOOK_DATA=$(cat)
# Parse and use HOOK_DATA as needed
```

## Troubleshooting

### Telegram notifications not sending
1. Check your internet connection
2. Verify bot token: `scripts/hooks/test_hooks.sh telegram`
3. Verify chat ID is correct
4. Check bot permissions in your Telegram chat

### Raycast notifications not showing
1. Ensure Raycast is installed and running
2. Check macOS notification permissions for Raycast
3. Try: `osascript -e 'display notification "test" with title "test"'`

### Hooks not triggering
1. Verify hooks are executable: `ls -la scripts/hooks/*.sh`
2. Check Claude Code settings configuration
3. Review Claude Code logs for hook errors

## Environment Variables

Optional environment variables you can set:

```bash
# Telegram Configuration
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"
```

## Example Notification Flow

```
1. You ask Claude to implement a feature
2. Claude analyzes the code
3. Claude needs approval → approval_hook.sh triggers
   ├─ Raycast notification appears on Mac
   ├─ Telegram message sent to your chat
   └─ Sound plays (Ping)
4. You approve the changes
5. Claude implements the feature
6. Task completes → completion_hook.sh triggers
   ├─ Raycast notification appears
   ├─ Telegram message sent
   └─ Sound plays (Glass)
```

## Security Notes

- Bot token is hardcoded for convenience - consider using environment variables for production
- Hooks run with your user permissions
- Review hook scripts before enabling them in Claude Code

## Support

For issues or questions:
- Check Claude Code documentation: https://claude.com/code
- Review hook execution in Claude Code logs
- Test individual components with the test script
