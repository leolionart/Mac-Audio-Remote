# FAQ - Confirmation Pattern

## General Questions

### Q: Tại sao cần confirmation pattern?

**A:** Trước đây, iOS Shortcuts nhận response ngay lập tức nhưng không biết liệu microphone có thực sự mute trong Google Meet không. Với confirmation pattern:
- ✅ Đảm bảo mute thành công
- ✅ Phát hiện khi extension không chạy
- ✅ State đồng bộ với actual UI

### Q: Latency tăng bao nhiêu?

**A:**
- **Confirmation mode:** ~100ms (đợi extension confirm)
- **Fast mode:** ~1ms (không đợi)
- **Trade-off:** Reliability vs Speed

### Q: Có cần Chrome Extension không?

**A:** Phụ thuộc vào use case:
- **Có Extension:** Use `/toggle-mic` (with confirmation)
- **Không Extension:** Use `/toggle-mic/fast` (optimistic)

Nếu không có extension, confirmation mode sẽ timeout sau 3 giây.

---

## Setup Questions

### Q: Làm sao install Chrome Extension?

**A:**
```bash
1. Mở chrome://extensions
2. Bật "Developer mode"
3. Click "Load unpacked"
4. Chọn folder: examples/chrome-extension
```

### Q: Extension có ở Chrome Web Store không?

**A:** Chưa. Hiện tại chỉ có unpacked extension. Chrome Web Store distribution sẽ có trong tương lai.

### Q: Có support Firefox/Safari không?

**A:** Chưa. Hiện tại chỉ support Chrome/Edge (Chromium-based browsers).

---

## Troubleshooting

### Q: iOS Shortcuts timeout sau 3 giây

**Symptom:**
```json
{"status":"timeout","muted":false}
```

**Nguyên nhân:**
1. Chrome Extension không chạy
2. Không ở trong Google Meet call
3. Extension crashed

**Giải pháp:**
```bash
# 1. Check extension status
chrome://extensions → MicDrop Bridge should be "Enabled"

# 2. Verify URL
# Must be in: meet.google.com/xxx-xxxx-xxx

# 3. Check Console logs
# Cmd+Option+J → Should see: 🔄 Starting long-poll loop
```

**Workaround:** Use fast mode
```
URL: http://localhost:8765/toggle-mic/fast
```

---

### Q: Extension không nhận events

**Symptom:** Long-poll không return hoặc không thấy events trong Console

**Debug:**
```bash
# Terminal 1: Monitor events
./scripts/monitor_events.sh

# Terminal 2: Trigger event
curl -X POST http://localhost:8765/toggle-mic/fast

# Terminal 1 should show event
```

**Kiểm tra:**
```javascript
// Chrome Console on meet.google.com
// Should see:
📡 Listening for events...
```

**Giải pháp:**
1. Reload extension: `chrome://extensions` → Reload
2. Reload Meet tab: `Cmd+R`
3. Check server: `lsof -i :8765`

---

### Q: Microphone không toggle trong Meet

**Symptom:** Extension nhận event nhưng mic không thay đổi

**Nguyên nhân:** Google Meet UI selectors thay đổi

**Debug:**
```javascript
// Chrome Console
document.querySelector('[aria-label*="microphone"]')
// Should return button element, not null
```

**Giải pháp:** Update selectors trong `content.js`:
```javascript
function getMeetMuteState() {
  const selectors = [
    '[data-is-muted="true"]',
    '[aria-label*="Turn off microphone"]',
    // Add new selector here
  ];
  // ...
}
```

---

### Q: State không đồng bộ

**Symptom:** Server shows `muted:true` nhưng Meet shows unmuted

**Nguyên nhân:** Extension gửi assumed state thay vì actual state

**Kiểm tra:**
```javascript
// In content.js
async function sendConfirmation() {
  // ❌ WRONG: Assumed state
  const isMuted = !wasAlreadyMuted;

  // ✅ CORRECT: Actual state from DOM
  const isMuted = getMeetMuteState();
}
```

**Giải pháp:** Always get state from DOM

---

### Q: Port 8765 already in use

**Symptom:**
```
⚠️ Port 8765 not available
```

**Giải pháp:**
```bash
# Check what's using port
lsof -i :8765

# Kill old process
killall AudioRemote

# Restart
.build/debug/AudioRemote
```

---

## Performance Questions

### Q: Có thể giảm confirmation timeout không?

**A:** Có, nhưng không khuyến khích. Modify trong `HTTPServer.swift`:
```swift
// Default: 3 seconds
let success = await bridgeManager.toggleWithConfirmation(timeout: 3.0)

// Faster but riskier:
let success = await bridgeManager.toggleWithConfirmation(timeout: 1.0)
```

**Trade-off:** Timeout ngắn hơn = nhiều false timeouts trên network chậm

---

### Q: Long-polling có tốn bandwidth không?

**A:** Không. Long-poll chỉ active khi có event. Khi idle:
- CPU: <1%
- Memory: ~5MB
- Network: 0 bytes/s (chỉ hold connection)

---

### Q: Có thể dùng WebSocket thay long-polling không?

**A:** Future enhancement. Hiện tại long-polling đủ tốt vì:
- ✅ Simple implementation
- ✅ No extra dependencies
- ✅ Works through most proxies
- ✅ ~100ms latency acceptable

---

## iOS Shortcuts Questions

### Q: Shortcut có thể detect mute state không?

**A:** Có, parse JSON response:
```
Get Contents of URL: http://...8765/status
Get Dictionary Value "muted" from Response
If [muted] is true → Show "Muted 🔇"
```

### Q: Có thể mute nhiều Shortcuts cùng lúc không?

**A:** Có, server handle concurrent requests. All requests sẽ receive cùng confirmation.

### Q: Làm sao retry khi timeout?

**A:** Add loop trong Shortcut:
```
Repeat 3 times:
  Get Contents of URL (POST /toggle-mic)
  Get Dictionary Value "status"
  If status = "ok" → Exit loop
  Wait 1 second
```

---

## Extension Development Questions

### Q: Có thể customize timeout trong extension không?

**A:** Không. Timeout controlled by server (3s). Extension chỉ gửi confirmation ASAP.

### Q: Extension có persist state không?

**A:** Không cần. State stored server-side. Extension chỉ là bridge.

### Q: Có thể add support cho Zoom/Teams không?

**A:** Có! Copy `content.js` và modify selectors:
```javascript
// Zoom selectors
const selectors = [
  '[aria-label*="Mute"]',
  '.footer-button__button--mute'
];
```

Update `manifest.json`:
```json
"content_scripts": [{
  "matches": [
    "https://meet.google.com/*",
    "https://*.zoom.us/*"
  ]
}]
```

---

## Security Questions

### Q: Server có authentication không?

**A:** Không. Server chỉ listen `localhost`, không expose ra internet.

### Q: Extension có quyền gì?

**A:**
- `activeTab` - Chỉ access tab đang active
- `meet.google.com` - Chỉ chạy trên Meet

Không có quyền: cookies, browsing history, hoặc tabs khác.

### Q: Data có được gửi ra ngoài không?

**A:** Không. Tất cả communication là local:
```
iOS (local network) → Mac (localhost:8765) → Extension (same Mac)
```

---

## Advanced Questions

### Q: Có thể track multiple confirmation requests không?

**A:** Hiện tại tất cả confirmations share chung queue. Future enhancement: request IDs.

### Q: Làm sao implement retry logic?

**A:** Server-side retry:
```swift
var attempts = 0
while attempts < 3 {
    let success = await toggleWithConfirmation(timeout: 2.0)
    if success { break }
    attempts += 1
    try await Task.sleep(nanoseconds: 500_000_000)
}
```

### Q: Có thể customize confirmation response không?

**A:** Có, modify `ToggleResponse` struct:
```swift
struct ToggleResponse: Content {
    let status: String
    let muted: Bool
    let latency: Int?  // Add custom fields
    let timestamp: Date?
}
```

---

## Migration Questions

### Q: Old shortcuts có cần update không?

**A:** Không! Default endpoint `/toggle-mic` giờ đợi confirmation, nhưng vẫn trả về response (với timeout nếu cần).

### Q: Có thể rollback về old behavior không?

**A:** Có, use `/toggle-mic/fast`:
```bash
# Old behavior (optimistic)
curl -X POST http://localhost:8765/toggle-mic/fast
```

### Q: Extension cũ có compatible không?

**A:** Không có extension cũ. Đây là feature mới.

---

## Debugging Questions

### Q: Làm sao enable verbose logging?

**A:** Modify `content.js`:
```javascript
const DEBUG = true;

function log(...args) {
  if (DEBUG) console.log('[MicDrop]', ...args);
}

// Use everywhere:
log('Event received:', event);
```

### Q: Làm sao monitor all events?

**A:**
```bash
./scripts/monitor_events.sh
```

Hoặc manual:
```bash
curl -s http://localhost:8765/bridge/poll
```

### Q: Có test suite không?

**A:** Có:
```bash
./scripts/test_confirmation.sh     # Automated tests
./scripts/demo_confirmation.sh     # Interactive demo
./scripts/monitor_events.sh        # Real-time monitor
```

---

## Still Have Questions?

1. **Check Documentation:**
   - Quick Start: `docs/QUICK_START_CONFIRMATION.md`
   - Full Guide: `docs/EXTENSION_INTEGRATION.md`
   - Testing: `docs/TESTING_GUIDE.md`

2. **Run Diagnostics:**
   ```bash
   ./scripts/test_confirmation.sh
   ```

3. **Check Logs:**
   ```bash
   # Server logs
   .build/debug/AudioRemote 2>&1 | tee debug.log

   # Extension logs
   Chrome DevTools Console (Cmd+Option+J)
   ```

4. **Create GitHub Issue:**
   - Include logs
   - Steps to reproduce
   - System info (macOS version, Swift version)
