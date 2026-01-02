# iOS Shortcuts Setup Guide

## 📱 Quick Import Shortcuts

### Cách 1: Import trực tiếp từ iCloud Links (Recommended)

Scan QR codes hoặc mở links sau trên iPhone:

**Microphone Control:**
- Toggle Mic: [Import Shortcut](shortcuts://import-shortcut?url=https://www.icloud.com/shortcuts/)
- Check Mic Status: [Import Shortcut](shortcuts://import-shortcut?url=https://www.icloud.com/shortcuts/)

**Volume Control:**
- Volume Up: [Import Shortcut](shortcuts://import-shortcut?url=https://www.icloud.com/shortcuts/)
- Volume Down: [Import Shortcut](shortcuts://import-shortcut?url=https://www.icloud.com/shortcuts/)
- Toggle Mute: [Import Shortcut](shortcuts://import-shortcut?url=https://www.icloud.com/shortcuts/)

### Cách 2: Manual Setup (Step-by-step)

#### 1. Toggle Microphone Shortcut

1. Mở **Shortcuts** app trên iPhone
2. Tap **+** (góc trên bên phải)
3. Tap **Add Action**
4. Tìm và chọn **Get Contents of URL**
5. Cấu hình:
   - **URL**: `http://YOUR_MAC_IP:8765/toggle-mic`
   - **Method**: `POST`
   - **Headers**: (để trống)
6. (Optional) Thêm **Show Notification** action:
   - Tap **+** để add action
   - Chọn **Show Notification**
   - Text: `Mic toggled!`
7. Tap **Done**
8. Đặt tên: `Toggle Mac Mic`
9. (Optional) Add to Home Screen:
   - Tap ⋯ (More)
   - Chọn **Add to Home Screen**
   - Chọn icon và màu
   - Tap **Add**

#### 2. Volume Up Shortcut

1. Tạo shortcut mới
2. Add **Get Contents of URL**
3. Cấu hình:
   - **URL**: `http://YOUR_MAC_IP:8765/volume/increase`
   - **Method**: `POST`
4. (Optional) Add **Show Notification**: `Volume increased!`
5. Tên: `Mac Vol Up`

#### 3. Volume Down Shortcut

1. Tạo shortcut mới
2. Add **Get Contents of URL**
3. Cấu hình:
   - **URL**: `http://YOUR_MAC_IP:8765/volume/decrease`
   - **Method**: `POST`
4. (Optional) Add **Show Notification**: `Volume decreased!`
5. Tên: `Mac Vol Down`

#### 4. Toggle Mute Shortcut

1. Tạo shortcut mới
2. Add **Get Contents of URL**
3. Cấu hình:
   - **URL**: `http://YOUR_MAC_IP:8765/volume/toggle-mute`
   - **Method**: `POST`
4. (Optional) Add **Show Notification**: `Volume muted!`
5. Tên: `Mac Mute`

#### 5. Check Status Shortcut (Advanced)

1. Tạo shortcut mới
2. Add **Get Contents of URL**:
   - **URL**: `http://YOUR_MAC_IP:8765/status`
   - **Method**: `GET`
3. Add **Get Dictionary Value**:
   - Key: `muted`
   - Dictionary: `Contents of URL`
4. Add **If** action:
   - If `Dictionary Value` is `true`
   - Then: **Show Notification** "Mic is MUTED 🔇"
   - Otherwise: **Show Notification** "Mic is ACTIVE 🎤"
5. Tên: `Check Mac Mic`

## 🎯 Find Your Mac IP Address

Có 3 cách để lấy IP của Mac:

### Cách 1: Từ Audio Remote App
1. Mở **Audio Remote** từ menu bar
2. Click **Settings...**
3. Xem trong phần **Network Info** → Local IP hiển thị IP address

### Cách 2: System Settings
1. Mở **System Settings**
2. Đi tới **Network**
3. Chọn **Wi-Fi** (hoặc Ethernet)
4. IP address hiển thị bên phải

### Cách 3: Terminal
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

## 🔧 Replace YOUR_MAC_IP

Trong mỗi shortcut, thay `YOUR_MAC_IP` bằng IP thật của Mac, ví dụ:
- Before: `http://YOUR_MAC_IP:8765/toggle-mic`
- After: `http://192.168.1.100:8765/toggle-mic`

## 🏠 Add to Home Screen

Để access nhanh:
1. Mở shortcut
2. Tap ⋯ (More button)
3. Chọn **Add to Home Screen**
4. Customize icon và tên
5. Tap **Add**

## 🎨 Widget Support

iOS 14+ hỗ trợ Shortcuts widgets:
1. Long press vào Home Screen
2. Tap **+** (góc trên bên trái)
3. Tìm **Shortcuts**
4. Chọn widget size
5. Tap **Add Widget**
6. Edit widget để chọn shortcuts

## 🔐 Security Notes

- ⚠️ Shortcuts chỉ hoạt động khi iPhone và Mac trên cùng Wi-Fi network
- ⚠️ Không cần authentication (local network only)
- ℹ️ Port mặc định: 8765 (có thể thay đổi trong Settings)

## 📊 All Available Endpoints

### Microphone Control
```
POST /toggle-mic          - Toggle microphone on/off
GET  /status              - Get mic status (muted: true/false)
```

### Volume Control
```
POST /volume/increase     - Increase volume by 10% (configurable)
POST /volume/decrease     - Decrease volume by 10% (configurable)
POST /volume/set          - Set exact volume (body: {"volume": 0.5})
POST /volume/toggle-mute  - Toggle volume mute
GET  /volume/status       - Get volume status
```

### Response Format
```json
{
  "status": "ok",
  "muted": false,
  "volume": 0.5
}
```

## 🆘 Troubleshooting

### Shortcut không hoạt động
1. Kiểm tra iPhone và Mac trên cùng Wi-Fi
2. Verify IP address đúng
3. Check HTTP Server enabled trong Settings
4. Test bằng Safari: mở `http://YOUR_MAC_IP:8765`

### Connection timeout
1. Check Mac firewall settings
2. Ensure Audio Remote app đang chạy
3. Try ping Mac IP từ iPhone

### Shortcuts app crash
1. Restart Shortcuts app
2. Re-create shortcut từ đầu
3. Update iOS to latest version

## 📱 Example: Complete Setup

1. Get Mac IP: `192.168.1.100`
2. Create "Toggle Mic" shortcut → Add to Home Screen
3. Create "Vol Up" shortcut → Add to Widget
4. Create "Vol Down" shortcut → Add to Widget
5. Use Siri: "Hey Siri, Toggle Mac Mic"

Enjoy remote control! 🎉
