# Testing Guide - Confirmation Pattern

Hướng dẫn test đầy đủ cho MicDrop Bridge confirmation pattern.

## Prerequisites

1. **Build MicDrop Server:**
   ```bash
   swift build
   .build/debug/AudioRemote
   ```

2. **Chrome Extension loaded** (optional for some tests)
   - `chrome://extensions` → Load `examples/chrome-extension`

## Test Suite Overview

| Test | Script | Description |
|------|--------|-------------|
| Basic | `test_confirmation.sh` | Automated test suite |
| Interactive | `demo_confirmation.sh` | Visual demo with colored output |
| Monitor | `monitor_events.sh` | Real-time event viewer |
| Manual | (below) | Step-by-step manual tests |

---

## 1. Automated Test Suite

**Run all tests:**
```bash
./scripts/test_confirmation.sh
```

**Expected output:**
```
🧪 MicDrop Bridge Confirmation Test
====================================

Test 1: Server Health Check
✅ Server is running

Test 2: Check Current State
Current state: muted=false

Test 3: Fast Toggle (No Confirmation)
✅ Fast toggle successful
Latency: 15ms

Test 4: Confirmation Timeout Test
✅ Timeout behavior works correctly
✅ Timeout duration correct (~3s)
Latency: 3012ms

Test 5: Successful Confirmation Test
✅ Confirmation successful
✅ Latency acceptable (<1s)
Latency: 524ms

Test 6: Long-Poll Event Test
✅ Long-poll received event
```

---

## 2. Interactive Demo

**Visual demonstration:**
```bash
./scripts/demo_confirmation.sh
```

Shows 3 scenarios:
1. ✅ Successful confirmation flow
2. ⏱️ Timeout scenario
3. 🚀 Fast mode (no confirmation)

---

## 3. Real-Time Event Monitor

**Monitor live events:**
```bash
# Terminal 1
./scripts/monitor_events.sh

# Terminal 2
curl -X POST http://localhost:8765/toggle-mic
```

**Expected output in Terminal 1:**
```
[14:23:45.123] 📡 Listening for events...
[14:23:46.456] 📢 Event Broadcast: MUTE-MIC
[14:23:46.789] 🔇 State Changed: MUTED
```

---

## 4. Manual Testing

### Test 4.1: Confirmation Success (Without Extension)

**Scenario:** Simulate extension confirmation manually

```bash
# Terminal 1: Start toggle (will wait)
curl -X POST http://localhost:8765/toggle-mic &

# Terminal 2: Send confirmation within 3s
sleep 1
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d '{"muted": true}'
```

**Expected:**
- Terminal 1 receives response within ~1s
- Response: `{"status":"ok","muted":true}`

**Validation:**
```bash
curl http://localhost:8765/status
# Should show: "muted":true
```

---

### Test 4.2: Confirmation Timeout

**Scenario:** Toggle without sending confirmation

```bash
# Don't send confirmation - should timeout
time curl -X POST http://localhost:8765/toggle-mic
```

**Expected:**
- Takes ~3 seconds
- Response: `{"status":"timeout","muted":false}`
- Time: `real 0m3.XXXs`

---

### Test 4.3: Fast Mode

**Scenario:** Legacy optimistic toggle

```bash
time curl -X POST http://localhost:8765/toggle-mic/fast
```

**Expected:**
- Takes <50ms
- Response: `{"status":"ok","muted":true}`
- Time: `real 0m0.0XXs`

---

### Test 4.4: Multiple Concurrent Requests

**Scenario:** Test confirmation queue

```bash
# Terminal 1
curl -X POST http://localhost:8765/toggle-mic &
PID1=$!

# Terminal 2
curl -X POST http://localhost:8765/toggle-mic &
PID2=$!

# Terminal 3: Send single confirmation
sleep 1
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d '{"muted": true}'

# Wait for both
wait $PID1
wait $PID2
```

**Expected:**
- Both requests receive confirmation
- Both return: `{"status":"ok",...}`

---

### Test 4.5: State Persistence

**Scenario:** Verify state doesn't desync

```bash
# Get initial state
curl http://localhost:8765/status | jq '.muted'
# Output: false

# Toggle with confirmation
curl -X POST http://localhost:8765/toggle-mic/fast

# Verify state changed
curl http://localhost:8765/status | jq '.muted'
# Output: true

# Manually set state
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d '{"muted": false}'

# Verify manual state update
curl http://localhost:8765/status | jq '.muted'
# Output: false
```

---

### Test 4.6: Long-Poll Behavior

**Scenario:** Test event broadcasting

```bash
# Terminal 1: Start long-poll listener
curl -s http://localhost:8765/bridge/poll

# Terminal 2: Trigger event
curl -X POST http://localhost:8765/toggle-mic/fast

# Terminal 1 should receive:
# {"event":"toggle-mic"}
```

**Validate multiple listeners:**
```bash
# Terminal 1
curl -s http://localhost:8765/bridge/poll &

# Terminal 2
curl -s http://localhost:8765/bridge/poll &

# Terminal 3: Trigger
curl -X POST http://localhost:8765/toggle-mic/fast

# Both Terminal 1 & 2 should receive event
```

---

## 5. Chrome Extension Testing

### Test 5.1: Extension Installation

1. Open `chrome://extensions`
2. Load `examples/chrome-extension`
3. Click extension icon → Should see:
   ```
   ✅ Connected to MicDrop Server
   ```

### Test 5.2: Extension Console Logs

1. Open Google Meet: `meet.google.com/xxx-xxxx-xxx`
2. Open DevTools: `Cmd+Option+J`
3. Check Console:
   ```
   🎤 MicDrop Bridge loaded for Google Meet
   🚀 Initializing MicDrop Bridge
   ✅ MicDrop Server connected
   ✅ Meet UI ready
   🔄 Starting long-poll loop
   📡 Listening for events...
   ```

### Test 5.3: Full Integration Test

**Prerequisites:**
- MicDrop Server running
- Chrome Extension loaded
- In Google Meet call

**Test:**
```bash
# Trigger toggle
curl -X POST http://localhost:8765/toggle-mic
```

**Expected Chrome Console:**
```
📥 Received event: mute-mic
Clicking microphone button: [selector]
Detected mute state: true
📤 Sending confirmation: muted=true
✅ Confirmation sent successfully
```

**Expected Response:**
```json
{"status":"ok","muted":true}
```

**Validation:**
- Microphone icon in Meet shows muted
- Response received within ~100ms
- Server logs show: `✅ Confirmation received`

---

## 6. Performance Testing

### Test 6.1: Latency Benchmark

**Test confirmation latency:**
```bash
for i in {1..10}; do
    echo "Test $i:"
    time curl -X POST http://localhost:8765/toggle-mic/fast
    echo ""
done
```

**Expected:** <50ms average

### Test 6.2: Confirmation Overhead

**Compare fast vs confirmation:**
```bash
echo "Fast mode (10 requests):"
time for i in {1..10}; do
    curl -s -X POST http://localhost:8765/toggle-mic/fast > /dev/null
done

echo ""
echo "Confirmation mode (10 requests, will timeout):"
time for i in {1..10}; do
    curl -s -X POST http://localhost:8765/toggle-mic > /dev/null
done
```

**Expected:**
- Fast: <1s total (~5ms per request)
- Confirmation: ~30s total (~3000ms timeout per request)

---

## 7. Error Handling Tests

### Test 7.1: Server Restart During Toggle

```bash
# Terminal 1: Start toggle
curl -X POST http://localhost:8765/toggle-mic &

# Terminal 2: Kill server
killall AudioRemote

# Terminal 1 should error
# No response or connection error
```

### Test 7.2: Invalid Confirmation Data

```bash
# Send invalid JSON
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d 'invalid json'

# Expected: HTTP 400 Bad Request
```

### Test 7.3: Missing muted Field

```bash
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d '{}'

# Expected: HTTP 400 Bad Request
```

---

## 8. iOS Shortcuts Testing

### Test 8.1: Create Test Shortcut

1. Open **Shortcuts** app
2. Create new Shortcut
3. Add **Get Contents of URL**
   - URL: `http://YOUR_MAC_IP:8765/toggle-mic`
   - Method: POST
4. Add **Show Result**

### Test 8.2: Run Shortcut

**Expected:**
- With extension: `{"status":"ok","muted":true}` (~100ms)
- Without extension: `{"status":"timeout",...}` (~3000ms)

### Test 8.3: Network Error Handling

1. Stop MicDrop Server
2. Run Shortcut
3. **Expected:** Network error in Shortcuts

---

## 9. Regression Tests

**Ensure backward compatibility:**

```bash
# Old endpoints still work
curl -X POST http://localhost:8765/toggle-mic
curl http://localhost:8765/status
curl -X POST http://localhost:8765/volume/increase

# New endpoints
curl http://localhost:8765/bridge/poll
curl -X POST http://localhost:8765/bridge/mic-state \
    -H "Content-Type: application/json" \
    -d '{"muted": true}'
```

---

## 10. Troubleshooting Tests

### Debug: Check Server Logs

```bash
.build/debug/AudioRemote 2>&1 | tee /tmp/micdrop.log
```

### Debug: Verbose curl

```bash
curl -v -X POST http://localhost:8765/toggle-mic
```

### Debug: Check Port Usage

```bash
lsof -i :8765
```

---

## Test Checklist

- [ ] Automated test suite passes
- [ ] Interactive demo runs without errors
- [ ] Event monitor shows real-time events
- [ ] Confirmation success works
- [ ] Timeout behavior correct (~3s)
- [ ] Fast mode latency <50ms
- [ ] Long-poll receives events
- [ ] Extension installs correctly
- [ ] Full integration test passes
- [ ] iOS Shortcuts work
- [ ] Error handling graceful
- [ ] Backward compatibility maintained

---

## Reporting Issues

If tests fail, collect:

1. **Server logs:**
   ```bash
   .build/debug/AudioRemote 2>&1 | tee issue.log
   ```

2. **Test output:**
   ```bash
   ./scripts/test_confirmation.sh > test-results.txt 2>&1
   ```

3. **Extension logs:**
   - Chrome DevTools Console output

4. **System info:**
   ```bash
   sw_vers
   swift --version
   curl --version
   ```

Submit with issue description on GitHub.
