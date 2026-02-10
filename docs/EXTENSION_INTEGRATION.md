# Chrome Extension Integration Guide

## Overview

MicDrop Bridge sử dụng **long-polling + confirmation pattern** để đồng bộ trạng thái giữa macOS app và Chrome Extension.

## Architecture

```
iOS Shortcuts → MicDrop Server → Chrome Extension → Google Meet
                      ↑                    ↓
                      └─── Confirmation ───┘
```

## Endpoints

### 1. Long-Polling (Extension → Server)

Extension lắng nghe sự kiện từ server:

```javascript
// Extension continuously polls for events
async function pollForEvents() {
  while (true) {
    try {
      const response = await fetch('http://localhost:8765/bridge/poll');
      const { event } = await response.json();

      // Handle event
      switch (event) {
        case 'toggle-mic':
        case 'mute-mic':
          await muteGoogleMeet();
          break;
        case 'unmute-mic':
          await unmuteGoogleMeet();
          break;
      }

      // CRITICAL: Send confirmation after successful mute
      await sendConfirmation();

    } catch (error) {
      console.error('Poll error:', error);
      await sleep(1000); // Retry after 1s
    }
  }
}
```

### 2. State Confirmation (Extension → Server)

**QUAN TRỌNG:** Extension PHẢI gửi confirmation sau khi thực hiện mute thành công:

```javascript
async function sendConfirmation() {
  // Get actual state from Google Meet DOM
  const isMuted = getMeetMuteState();

  await fetch('http://localhost:8765/bridge/mic-state', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ muted: isMuted })
  });
}
```

### 3. Toggle Endpoint (iOS Shortcuts → Server)

iOS Shortcuts gọi endpoint này và **đợi confirmation**:

```bash
# Default: Waits for extension confirmation (3s timeout)
curl -X POST http://localhost:8765/toggle-mic

# Response sau khi extension confirm:
{"status":"ok","muted":true}

# Response khi timeout (extension không phản hồi):
{"status":"timeout","muted":false}
```

```bash
# Fast mode: No waiting (legacy behavior)
curl -X POST http://localhost:8765/toggle-mic/fast
```

## Flow Diagram

### Successful Toggle with Confirmation

```
1. iOS Shortcuts
   ↓ POST /toggle-mic
2. MicDrop Server
   ↓ Broadcast "mute-mic" event
   ↓ Wait for confirmation (3s timeout)
3. Chrome Extension
   ↓ Receives event from long-poll
   ↓ Click mute button in Google Meet
   ↓ Verify mute state from DOM
   ↓ POST /bridge/mic-state with actual state
4. MicDrop Server
   ↓ Resume confirmation continuation
   ↓ Return response to iOS Shortcuts
5. iOS Shortcuts
   ✅ Receives {"status":"ok","muted":true}
```

### Timeout Scenario

```
1. iOS Shortcuts
   ↓ POST /toggle-mic
2. MicDrop Server
   ↓ Broadcast "mute-mic" event
   ↓ Wait for confirmation (3s timeout)
3. Chrome Extension
   ✗ Extension not running / crashed
   ✗ No confirmation received
4. MicDrop Server (after 3s)
   ↓ Timeout continuation
   ↓ Return timeout response
5. iOS Shortcuts
   ⚠️ Receives {"status":"timeout","muted":false}
```

## Chrome Extension Implementation

### Required Functions

```javascript
// 1. Get actual mute state from Google Meet
function getMeetMuteState() {
  const muteButton = document.querySelector('[data-is-muted]');
  return muteButton?.getAttribute('data-is-muted') === 'true';
}

// 2. Click mute button
async function muteGoogleMeet() {
  const muteButton = document.querySelector('[aria-label*="microphone"]');
  muteButton?.click();

  // Wait for DOM update
  await sleep(100);
}

// 3. Send confirmation
async function sendConfirmation() {
  const isMuted = getMeetMuteState();

  await fetch('http://localhost:8765/bridge/mic-state', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ muted: isMuted })
  });
}

// 4. Long-polling loop
async function pollForEvents() {
  while (true) {
    try {
      const response = await fetch('http://localhost:8765/bridge/poll');
      const { event } = await response.json();

      if (event === 'mute-mic' || event === 'toggle-mic') {
        await muteGoogleMeet();
        await sendConfirmation(); // CRITICAL!
      } else if (event === 'unmute-mic') {
        await muteGoogleMeet(); // Toggle
        await sendConfirmation(); // CRITICAL!
      }

    } catch (error) {
      console.error('Poll error:', error);
      await sleep(1000);
    }
  }
}

// 5. Start on page load
if (window.location.hostname.includes('meet.google.com')) {
  pollForEvents();
}
```

## Testing

### Test Confirmation Flow

```bash
# Terminal 1: Monitor server logs
swift build && .build/debug/AudioRemote

# Terminal 2: Simulate extension confirmation
curl -X POST http://localhost:8765/toggle-mic &
sleep 1
curl -X POST http://localhost:8765/bridge/mic-state \
  -H "Content-Type: application/json" \
  -d '{"muted": true}'

# Expected output:
# ✅ Confirmation received for request <UUID>
```

### Test Timeout

```bash
# Don't send confirmation - should timeout after 3s
curl -X POST http://localhost:8765/toggle-mic

# Expected response after 3s:
# {"status":"timeout","muted":false}
```

## Migration Guide

### For existing iOS Shortcuts

**No changes needed!** The default endpoint now waits for confirmation.

If you want the old fast behavior:

```
Change URL: http://localhost:8765/toggle-mic
To: http://localhost:8765/toggle-mic/fast
```

### For Chrome Extension developers

**You MUST add confirmation:**

1. After every mute/unmute action, call `sendConfirmation()`
2. Always send actual state from DOM, not assumed state
3. Handle errors gracefully (retry on network failure)

## Troubleshooting

### iOS Shortcuts timeout

**Symptom:** Shortcut takes 3 seconds to return with `"status":"timeout"`

**Causes:**
1. Chrome Extension not running
2. Extension not calling `sendConfirmation()`
3. Network issue between extension and server

**Solution:**
```bash
# Check if extension is connected (should have active long-poll)
lsof -i :8765

# Check server logs for broadcast
# Should see: 📢 Bridge Event: mute-mic
```

### Extension not receiving events

**Symptom:** Long-poll returns but nothing happens in Google Meet

**Debug:**
```javascript
// Add logging in extension
console.log('Received event:', event);
console.log('Mute button found:', !!document.querySelector('[aria-label*="microphone"]'));
```

### State desync

**Symptom:** Server shows muted but Meet is unmuted

**Cause:** Extension sending assumed state instead of actual state

**Fix:**
```javascript
// ❌ WRONG: Assumed state
const isMuted = !wasAlreadyMuted;

// ✅ CORRECT: Actual state from DOM
const isMuted = getMeetMuteState();
```

## Performance

- **Latency:** ~100ms total (50ms broadcast + 50ms confirmation)
- **Timeout:** 3 seconds (configurable)
- **Fast mode:** ~1ms (no confirmation)

## Security

- Server only listens on `localhost:8765`
- No authentication needed (local-only)
- Extension can only be installed from Chrome Web Store (future)

## Future Enhancements

1. **Request IDs:** Track specific toggle requests
2. **Retry logic:** Auto-retry on confirmation timeout
3. **Multiple extensions:** Support Zoom, Teams, etc.
4. **WebSocket:** Replace long-polling for lower latency
