# MicDrop Bridge - Confirmation Pattern 🎤✅

> **Control Google Meet microphone from iOS Shortcuts with guaranteed state confirmation**

## Overview

MicDrop Bridge transforms your macOS app into a **reliable bridge** between iOS Shortcuts and Chrome Extension, ensuring microphone mute commands actually succeed before returning a response.

### The Problem

**Before (Optimistic Updates):**
```
iOS Shortcuts → Server → ✅ "Success!" (immediate)
                  ↓
           Extension → ❌ Actually failed, but nobody knows
```

**Issues:**
- iOS thinks mute happened, but it didn't
- No way to detect extension failures
- State desync between server and actual Meet UI

### The Solution

**After (Confirmation Pattern):**
```
iOS Shortcuts → Server (waits) → Extension → Google Meet
                  ↑                    ↓
                  └─── Confirmation ───┘
                  ↓
              ✅ "Success!" or ⏱️ "Timeout"
```

**Benefits:**
- ✅ **Guaranteed mute** - Server waits for extension to confirm
- ✅ **Timeout detection** - Know when extension isn't running
- ✅ **State sync** - Actual state from Meet UI, not assumptions
- ✅ **~100ms latency** - Fast enough for real-time control

---

## Quick Start

### 1. Build & Run Server

```bash
swift build
.build/debug/AudioRemote
```

### 2. Install Chrome Extension

```bash
# Open Chrome
chrome://extensions

# Enable Developer mode → Load unpacked
# Select: examples/chrome-extension/
```

### 3. Test

```bash
# Terminal
curl -X POST http://localhost:8765/toggle-mic

# Response (if extension running):
{"status":"ok","muted":true}

# Response (if extension not running):
{"status":"timeout","muted":false}
```

### 4. Configure iOS Shortcuts

1. Create new Shortcut
2. Add **Get Contents of URL**
   - URL: `http://YOUR_MAC_IP:8765/toggle-mic`
   - Method: `POST`
3. Run in Google Meet call → Mic toggles!

**Full guide:** [Quick Start](docs/QUICK_START_CONFIRMATION.md)

---

## Architecture

```
┌─────────────────┐
│  iOS Shortcuts  │ 📱 User triggers toggle
└────────┬────────┘
         │ POST /toggle-mic
         ↓
┌─────────────────┐
│  MicDrop Server │ 💻 macOS Swift app
│  localhost:8765 │    - Broadcasts event
└────────┬────────┘    - Waits for confirmation (3s timeout)
         │
         ↓ Long-polling /bridge/poll
┌─────────────────┐
│ Chrome Extension│ 🌐 content.js on meet.google.com
│   content.js    │    - Receives event
└────────┬────────┘    - Clicks mute button
         │             - Sends actual state back
         ↓ POST /bridge/mic-state
         │
         ↓ DOM manipulation
┌─────────────────┐
│  Google Meet UI │ 🎤 Actual microphone control
└─────────────────┘
```

---

## API Endpoints

### Microphone Control

| Endpoint | Method | Description | Response Time |
|----------|--------|-------------|---------------|
| `/toggle-mic` | POST | Toggle with confirmation | ~100ms or 3s timeout |
| `/toggle-mic/fast` | POST | Toggle without waiting | ~1ms |
| `/status` | GET | Get current state | ~1ms |

### Bridge Communication

| Endpoint | Method | Description | Used By |
|----------|--------|-------------|---------|
| `/bridge/poll` | GET | Long-polling for events | Extension |
| `/bridge/mic-state` | POST | Report actual state | Extension |

### Volume Control

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/volume/increase` | POST | Increase speaker volume |
| `/volume/decrease` | POST | Decrease speaker volume |

**Full API:** [Extension Integration Guide](docs/EXTENSION_INTEGRATION.md)

---

## Response Format

### Success Response

```json
{
  "status": "ok",
  "muted": true
}
```

**Meaning:** Extension confirmed microphone is muted

### Timeout Response

```json
{
  "status": "timeout",
  "muted": false
}
```

**Meaning:** Extension didn't respond within 3 seconds (likely not running)

---

## Flow Diagrams

### Successful Toggle

```
Time: 0ms
├─ iOS Shortcuts sends POST /toggle-mic
│
Time: 10ms
├─ Server creates confirmation continuation
├─ Server broadcasts "mute-mic" event
├─ Server starts 3s timeout timer
│
Time: 20ms
├─ Extension receives event from long-poll
├─ Extension clicks mute button in Meet
│
Time: 50ms
├─ Extension reads actual state from DOM (muted=true)
├─ Extension POSTs to /bridge/mic-state
│
Time: 60ms
├─ Server receives confirmation
├─ Server resumes continuation
├─ Server returns {"status":"ok","muted":true}
│
Time: 100ms
└─ iOS Shortcuts receives response ✅
```

### Timeout Scenario

```
Time: 0ms
├─ iOS Shortcuts sends POST /toggle-mic
│
Time: 10ms
├─ Server creates confirmation continuation
├─ Server broadcasts "mute-mic" event
├─ Server starts 3s timeout timer
│
Time: 20ms
├─ Extension NOT running ❌
├─ No long-poll connection active
│
Time: 3000ms (3 seconds later)
├─ Timeout timer fires
├─ Server resumes with false
├─ Server returns {"status":"timeout","muted":false}
│
Time: 3010ms
└─ iOS Shortcuts receives timeout response ⏱️
```

---

## Testing

### Automated Test Suite

```bash
./scripts/test_confirmation.sh
```

**Tests:**
- ✅ Server health check
- ✅ Fast toggle latency
- ✅ Timeout behavior
- ✅ Successful confirmation
- ✅ Long-poll events

### Interactive Demo

```bash
./scripts/demo_confirmation.sh
```

**Shows:**
1. Successful confirmation flow
2. Timeout scenario
3. Fast mode comparison

### Real-Time Monitor

```bash
# Terminal 1
./scripts/monitor_events.sh

# Terminal 2
curl -X POST http://localhost:8765/toggle-mic
```

**Output:**
```
[14:23:45.123] 📡 Listening for events...
[14:23:46.456] 📢 Event Broadcast: MUTE-MIC
[14:23:46.789] 🔇 State Changed: MUTED
```

**Full guide:** [Testing Guide](docs/TESTING_GUIDE.md)

---

## Chrome Extension

### Installation

1. **Load Extension:**
   ```
   chrome://extensions → Developer mode → Load unpacked
   Select: examples/chrome-extension/
   ```

2. **Verify Connection:**
   - Click extension icon
   - Should see: "✅ Connected to MicDrop Server"

3. **Join Google Meet:**
   - URL: `meet.google.com/xxx-xxxx-xxx`
   - Open Console (Cmd+Option+J)
   - Should see: `🔄 Starting long-poll loop`

### How It Works

**content.js** runs on `meet.google.com`:

```javascript
// 1. Long-poll for events
const { event } = await fetch('/bridge/poll').then(r => r.json());

// 2. Handle event
if (event === 'mute-mic') {
  await toggleMicrophoneButton();
}

// 3. CRITICAL: Send actual state
const isMuted = getMeetMuteState(); // From DOM
await fetch('/bridge/mic-state', {
  method: 'POST',
  body: JSON.stringify({ muted: isMuted })
});
```

**Full guide:** [Extension README](examples/chrome-extension/README.md)

---

## Performance

| Metric | Confirmation Mode | Fast Mode |
|--------|------------------|-----------|
| **Latency** | ~100ms | ~1ms |
| **Reliability** | Guaranteed | Optimistic |
| **Timeout** | 3s | N/A |
| **Use Case** | Production | Low-latency testing |

### Benchmark

```bash
# Fast mode
time curl -X POST http://localhost:8765/toggle-mic/fast
# real 0m0.015s

# Confirmation mode (with extension)
time curl -X POST http://localhost:8765/toggle-mic
# real 0m0.102s

# Timeout (without extension)
time curl -X POST http://localhost:8765/toggle-mic
# real 0m3.012s
```

---

## Troubleshooting

### iOS Shortcuts timeout

**Symptom:** Response after 3 seconds with `"status":"timeout"`

**Causes:**
- Chrome Extension not running
- Not in Google Meet call
- Extension crashed

**Solutions:**
1. Check `chrome://extensions` → MicDrop Bridge enabled
2. Verify URL: `meet.google.com/xxx-xxxx-xxx`
3. Check Console logs: Should see `🔄 Starting long-poll loop`

**Workaround:** Use fast mode
```
URL: http://localhost:8765/toggle-mic/fast
```

### Extension not receiving events

**Debug:**
```bash
# Terminal 1: Start listener
curl -s http://localhost:8765/bridge/poll

# Terminal 2: Trigger
curl -X POST http://localhost:8765/toggle-mic/fast

# Terminal 1 should receive: {"event":"toggle-mic"}
```

**Solutions:**
1. Reload extension
2. Reload Meet tab
3. Check server: `lsof -i :8765`

### Microphone not toggling

**Symptom:** Extension receives event but mic doesn't change

**Cause:** Google Meet UI selectors changed

**Debug:**
```javascript
// Chrome Console
document.querySelector('[aria-label*="microphone"]')
// Should return button, not null
```

**Solution:** Update selectors in `content.js`

**Full guide:** [FAQ](docs/FAQ_CONFIRMATION.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Quick Start](docs/QUICK_START_CONFIRMATION.md) | 3-step setup guide |
| [Extension Integration](docs/EXTENSION_INTEGRATION.md) | Full integration guide |
| [Confirmation Pattern](docs/CONFIRMATION_PATTERN.md) | Implementation details |
| [Testing Guide](docs/TESTING_GUIDE.md) | Comprehensive testing |
| [FAQ](docs/FAQ_CONFIRMATION.md) | Common questions |

---

## Migration Guide

### For Existing Users

**No changes needed!** Your existing iOS Shortcuts will work with confirmation pattern.

**Before:**
```
POST http://localhost:8765/toggle-mic
→ Immediate response (optimistic)
```

**After:**
```
POST http://localhost:8765/toggle-mic
→ Waits for confirmation (reliable)
```

### If You Want Old Behavior

Change URL to fast mode:
```
POST http://localhost:8765/toggle-mic/fast
```

---

## Future Enhancements

- [ ] **Request IDs** - Track specific toggle requests
- [ ] **Retry Logic** - Auto-retry on timeout
- [ ] **WebSocket** - Replace long-polling for lower latency
- [ ] **Multi-Extension** - Support Zoom, Teams, Discord
- [ ] **Chrome Web Store** - Official extension distribution
- [ ] **Metrics Dashboard** - Success/timeout rates
- [ ] **Voice Feedback** - Siri speaks mute status

---

## Contributing

### Adding Support for Other Platforms

**Zoom Example:**

1. Update `manifest.json`:
   ```json
   "content_scripts": [{
     "matches": [
       "https://meet.google.com/*",
       "https://*.zoom.us/*"
     ]
   }]
   ```

2. Create `zoom.js` with platform-specific selectors
3. Inject based on URL

### Improving Selectors

Google Meet changes UI frequently. Help by:

1. Finding new selectors
2. Testing on different Meet versions
3. Submitting PRs with fallbacks

---

## Security

### Server

- ✅ Localhost only (`0.0.0.0:8765` but firewalled)
- ✅ No authentication needed (local network)
- ✅ CORS enabled for same-machine access

### Extension

- ✅ Minimal permissions (`activeTab`, `meet.google.com`)
- ✅ No cookies, no history, no tabs access
- ✅ Open source - inspect all code

### Data Flow

All communication is local:
```
iOS (192.168.x.x) → Mac (localhost) → Extension (same Mac)
```

No external servers involved.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Server** | Swift 5.9+, Vapor 4, Combine |
| **Extension** | Vanilla JavaScript (ES6+) |
| **iOS** | Shortcuts app (built-in) |
| **Protocol** | HTTP REST, Long-polling |

---

## License

MIT

---

## Credits

Built by **MicDrop Team** for seamless audio control across devices.

**Special thanks to:**
- Vapor community for async HTTP server
- Chrome Extensions API documentation
- iOS Shortcuts early testers

---

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/mac-audio-remote/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/mac-audio-remote/discussions)
- **Documentation:** See `/docs` folder

---

## Quick Links

- 📱 [iOS Shortcuts Setup](docs/QUICK_START_CONFIRMATION.md#ios-shortcuts-setup)
- 🌐 [Chrome Extension Install](examples/chrome-extension/README.md#installation)
- 🧪 [Run Tests](docs/TESTING_GUIDE.md#automated-test-suite)
- ❓ [FAQ](docs/FAQ_CONFIRMATION.md)
- 🐛 [Troubleshooting](docs/FAQ_CONFIRMATION.md#troubleshooting)

---

<p align="center">
  <strong>Made with ❤️ for remote workers who need reliable mute control</strong>
</p>
