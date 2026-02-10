# Quick Start: Confirmation Pattern

## TL;DR

MicDrop giờ đây **đảm bảo** microphone thực sự mute trong Google Meet trước khi trả response cho iOS Shortcuts.

## Setup trong 3 bước

### Bước 1: Build & Run MicDrop Server

```bash
cd /path/to/mac-audio-remote
swift build
.build/debug/AudioRemote
```

Server sẽ chạy trên `localhost:8765`

### Bước 2: Install Chrome Extension

1. Mở Chrome → `chrome://extensions`
2. Bật **Developer mode**
3. Click **Load unpacked**
4. Chọn folder `examples/chrome-extension`
5. Extension sẽ hiện trên thanh công cụ Chrome

### Bước 3: Test

```bash
# Terminal 1: Monitor server logs
.build/debug/AudioRemote

# Terminal 2: Test toggle
curl -X POST http://localhost:8765/toggle-mic

# Kết quả (sau ~100ms):
{"status":"ok","muted":true}      ← Extension confirmed
# hoặc
{"status":"timeout","muted":false} ← Extension không phản hồi
```

## iOS Shortcuts Setup

### Tạo Shortcut mới

1. Mở **Shortcuts** app
2. Tap **+** → **Add Action**
3. Search **"Get Contents of URL"**
4. Configure:
   - **URL:** `http://YOUR_MAC_IP:8765/toggle-mic`
   - **Method:** POST
5. Done!

### Test Shortcut

1. Vào Google Meet call
2. Run Shortcut
3. Microphone sẽ toggle sau ~100ms

## Troubleshooting

### "status": "timeout"

**Nguyên nhân:**
- Chrome Extension không chạy
- Không ở trong Google Meet call
- Extension crash

**Giải pháp:**
```bash
# 1. Check extension
# Chrome → chrome://extensions
# MicDrop Bridge should show "Enabled"

# 2. Check URL
# Must be in: meet.google.com/xxx-xxxx-xxx

# 3. Check Console (Cmd+Option+J)
# Should see: 🎤 MicDrop Bridge loaded
```

### Extension không nhận event

**Check long-poll:**
```bash
# Terminal 1: Start poll listener
curl -s http://localhost:8765/bridge/poll

# Terminal 2: Trigger event
curl -X POST http://localhost:8765/toggle-mic/fast

# Terminal 1 should receive: {"event":"toggle-mic"}
```

### Muốn fast mode (không đợi)

Change Shortcut URL:
```
Từ: http://localhost:8765/toggle-mic
Sang: http://localhost:8765/toggle-mic/fast
```

**Trade-off:**
- ✅ Latency: ~1ms (nhanh hơn 100x)
- ❌ Không biết có thực sự mute không

## How It Works

```
1. iOS Shortcuts gọi /toggle-mic
   ↓
2. MicDrop Server broadcast event
   ↓ (đợi confirmation, max 3s)
3. Chrome Extension nhận event
   ↓
4. Extension click mute trong Meet
   ↓
5. Extension gửi confirmation về server
   ↓
6. Server trả response cho iOS Shortcuts
   ✅ "status": "ok" (thành công)
   ⏱️ "status": "timeout" (hết thời gian)
```

## Full Documentation

- **Integration Guide:** `docs/EXTENSION_INTEGRATION.md`
- **Extension README:** `examples/chrome-extension/README.md`
- **Implementation Details:** `docs/CONFIRMATION_PATTERN.md`

## Need Help?

Run test suite:
```bash
./scripts/test_confirmation.sh
```

Check logs:
```bash
# Server logs
.build/debug/AudioRemote

# Extension logs
# Chrome DevTools Console (Cmd+Option+J) on meet.google.com
```
