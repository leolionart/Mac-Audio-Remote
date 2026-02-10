# MicDrop Bridge - Chrome Extension

Chrome Extension để điều khiển Google Meet microphone từ iOS Shortcuts qua MicDrop Server.

## Tính năng

- ✅ **Toggle microphone** trong Google Meet từ xa
- ✅ **Confirmation pattern** - đảm bảo mute thành công
- ✅ **Long-polling** - latency thấp, không cần WebSocket
- ✅ **Auto-reconnect** - tự động kết nối lại khi mất kết nối
- ✅ **State sync** - đồng bộ trạng thái thực tế từ Meet UI

## Cài đặt

### 1. Build MicDrop Server

```bash
cd /path/to/mac-audio-remote
swift build -c release
.build/release/AudioRemote
```

Server sẽ chạy trên `localhost:8765`

### 2. Load Extension vào Chrome

1. Mở Chrome → `chrome://extensions`
2. Bật **Developer mode** (góc trên bên phải)
3. Click **Load unpacked**
4. Chọn folder `examples/chrome-extension`

### 3. Kiểm tra kết nối

1. Click icon MicDrop Bridge trên thanh công cụ Chrome
2. Popup sẽ hiển thị trạng thái kết nối
3. Nếu thấy "✅ Connected" → sẵn sàng sử dụng!

## Sử dụng

### Từ iOS Shortcuts

```
1. Tạo Shortcut mới
2. Thêm action "Get Contents of URL"
   - URL: http://YOUR_MAC_IP:8765/toggle-mic
   - Method: POST
3. Run Shortcut → Microphone trong Meet sẽ toggle
```

### Test từ Terminal

```bash
# Toggle with confirmation (waits for extension)
curl -X POST http://localhost:8765/toggle-mic

# Response:
# {"status":"ok","muted":true}          ← Success
# {"status":"timeout","muted":false}    ← Extension didn't respond
```

### Test trên Google Meet

1. Vào https://meet.google.com/new
2. Mở DevTools Console (Cmd+Option+J)
3. Sẽ thấy logs:
   ```
   🎤 MicDrop Bridge loaded for Google Meet
   🚀 Initializing MicDrop Bridge
   ✅ MicDrop Server connected
   🔄 Starting long-poll loop
   ```
4. Chạy curl command → Mic sẽ toggle

## Kiến trúc

```
┌─────────────────┐
│  iOS Shortcuts  │
└────────┬────────┘
         │ POST /toggle-mic
         ↓
┌─────────────────┐
│  MicDrop Server │ ← Runs on macOS (Swift)
│  localhost:8765 │
└────────┬────────┘
         │ Long-polling /bridge/poll
         ↓
┌─────────────────┐
│ Chrome Extension│ ← Content script on meet.google.com
│   content.js    │
└────────┬────────┘
         │ Click mute button
         ↓
┌─────────────────┐
│  Google Meet UI │
└─────────────────┘
```

## Cách hoạt động

### 1. Extension khởi động

```javascript
// content.js runs on meet.google.com
pollForEvents(); // Start long-poll loop
```

### 2. iOS Shortcuts trigger

```bash
curl -X POST http://localhost:8765/toggle-mic
```

### 3. Server broadcast event

```swift
// HTTPServer.swift
let success = await bridgeManager.toggleWithConfirmation(timeout: 3.0)
```

### 4. Extension nhận event

```javascript
// content.js
const { event } = await fetch('/bridge/poll').then(r => r.json());
// event = "mute-mic"
```

### 5. Extension click nút mute

```javascript
const button = document.querySelector('[aria-label*="microphone"]');
button.click();
```

### 6. Extension gửi confirmation

```javascript
const isMuted = getMeetMuteState(); // Get ACTUAL state from DOM
await fetch('/bridge/mic-state', {
  method: 'POST',
  body: JSON.stringify({ muted: isMuted })
});
```

### 7. Server trả về response

```swift
// Server receives confirmation
return ToggleResponse(status: "ok", muted: muted)
```

### 8. iOS Shortcuts nhận kết quả

```json
{"status":"ok","muted":true}
```

## Troubleshooting

### Extension không nhận event

**Kiểm tra logs trong DevTools Console:**

```javascript
// Nếu thấy lỗi Poll:
❌ Poll error: TypeError: Failed to fetch

// → Server không chạy hoặc bị firewall block
```

**Giải pháp:**
```bash
# Restart server
killall AudioRemote
.build/release/AudioRemote

# Check port
lsof -i :8765
```

### iOS Shortcuts timeout

**Symptom:** Shortcut trả về sau 3 giây với `"status":"timeout"`

**Nguyên nhân:**
1. Extension không chạy
2. Không ở trong Google Meet call
3. Extension crash

**Giải pháp:**
```bash
# 1. Check extension status
# Open Chrome → chrome://extensions
# MicDrop Bridge should be "Enabled"

# 2. Check if in meeting
# URL must match: meet.google.com/xxx-xxxx-xxx

# 3. Check console logs
# Should see: 🔄 Starting long-poll loop
```

### Mute không hoạt động

**Kiểm tra selector:**

```javascript
// Google Meet UI thay đổi thường xuyên
// Test in Console:
document.querySelector('[aria-label*="microphone"]')

// Nếu null → Update selector in content.js
```

**Kiểm tra permissions:**

```bash
# Extension cần quyền truy cập meet.google.com
# manifest.json → host_permissions
```

## Development

### Debug Mode

Enable verbose logging:

```javascript
// In content.js, add at top:
const DEBUG = true;

function log(...args) {
  if (DEBUG) console.log('[MicDrop]', ...args);
}
```

### Test without iOS Shortcuts

```bash
# Terminal 1: Monitor server logs
.build/release/AudioRemote

# Terminal 2: Simulate iOS Shortcuts
while true; do
  curl -X POST http://localhost:8765/toggle-mic
  sleep 5
done
```

### Modify UI Selectors

Google Meet thay đổi HTML structure thường xuyên. Update selectors:

```javascript
// content.js
function getMeetMuteState() {
  const selectors = [
    // Add new selectors here
    '[data-is-muted="true"]',
    '[aria-label*="Turn off microphone"]',
    // Your custom selector
  ];
  // ...
}
```

## Security

- ✅ Chỉ chạy trên `meet.google.com`
- ✅ Server chỉ listen `localhost` (không remote access)
- ✅ Không có authentication (vì local-only)
- ✅ Không gửi data ra ngoài

## Performance

- **Latency:** ~100ms (broadcast + confirmation)
- **Long-poll timeout:** 30s (auto-reconnect)
- **Confirmation timeout:** 3s
- **CPU usage:** <1% (event-driven)
- **Memory:** ~5MB

## Roadmap

- [ ] Support Zoom, Teams, Discord
- [ ] WebSocket for lower latency
- [ ] Chrome Web Store distribution
- [ ] Auto-update mechanism
- [ ] Multi-tab support
- [ ] Keyboard shortcuts

## License

MIT

## Credits

Built for MicDrop - macOS menu bar app for audio control
