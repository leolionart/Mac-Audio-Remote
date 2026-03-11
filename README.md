# 🎤 MicDrop

Ứng dụng macOS menu bar + Chrome Extension để điều khiển microphone Google Meet từ xa — qua phím tắt toàn cục, iOS Shortcuts, hoặc bất kỳ HTTP client nào.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Chrome](https://img.shields.io/badge/Chrome-Extension-orange.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)

![MicDrop Screenshot](docs/screenshots/screenshot-1.png)

## Cách hoạt động

```
iPhone (Shortcuts)
       │  HTTP POST /toggle-mic
       ▼
MicDrop App (macOS)  ──── Long-polling ────  Chrome Extension
  • HTTP server :8765                              │
  • Menu bar icon                                  ▼
  • Volume HUD                              Google Meet UI
  • Mic state HUD                           (click mute button)
```

1. **MicDrop App** chạy HTTP server tại port 8765, lắng nghe phím tắt `⌥M`
2. **Chrome Extension** kết nối với app qua long-polling, nhận lệnh và điều khiển Meet UI
3. **iOS Shortcuts** gửi HTTP request đến app, app forward sang Extension và chờ xác nhận

---

## Cài đặt

### Bước 1 — Cài macOS App

1. Vào trang [**Releases**](https://github.com/leolionart/Mac-Audio-Remote/releases/latest)
2. Tải file **`MicDrop-x.x.x.dmg`** (hoặc `.zip`)
3. Mở DMG → kéo `MicDrop.app` vào `/Applications`
4. **Quan trọng** — Lần đầu mở app, macOS sẽ chặn vì app không có chữ ký App Store. Chạy lệnh sau để bỏ quarantine:
   ```bash
   xattr -c /Applications/MicDrop.app
   ```
5. Mở app — icon xuất hiện trên menu bar

<details>
<summary>Build từ source</summary>

```bash
swift build -c release
./scripts/build_app_bundle.sh
```
</details>

---

### Bước 2 — Cài Chrome Extension

1. Mở Chrome → vào `chrome://extensions`
2. Bật **Developer mode** (góc trên phải)
3. Click **Load unpacked**
4. Chọn thư mục `chrome-extension/` từ repo này
5. Extension xuất hiện trên thanh công cụ Chrome

> Extension tự động phát hiện tab Google Meet và kết nối với app.

---

### Bước 3 — Cài iOS Shortcut (tuỳ chọn)

Tạo Shortcut với các bước sau:

| # | Action | Cấu hình |
|---|--------|----------|
| 1 | **Get Contents of URL** | URL: `http://<IP_MAC>:8765/toggle-mic` · Method: `POST` |
| 2 | **Get Dictionary from** | Input: `Contents of URL` |
| 3 | **Get Value for Key** | Key: `muted` · Dictionary: `Dictionary` |
| 4 | **Text** | Nội dung: biến `[Dictionary Value]` |
| 5 | **If** `[Text]` **is** `"true"` | → Notification: `🔇 Đã tắt mic` |
| 6 | **Otherwise** | → Notification: `🎤 Đã mở mic` |

> Tìm IP Mac: **System Settings → Wi-Fi → Details → IP Address**

---

## Tính năng

### Điều khiển Microphone
| Cách | Mô tả |
|------|-------|
| `⌥M` | Phím tắt toàn cục (hoạt động kể cả khi Chrome ở nền) |
| iOS Shortcut | Điều khiển từ xa qua Wi-Fi, phản hồi xác nhận từ Meet |
| Menu bar | Click icon để toggle |

### Điều khiển Volume hệ thống
- Tăng/giảm/đặt âm lượng qua iOS Shortcuts
- HUD hiển thị mức volume khi thay đổi
- Toggle mute speaker

### Chrome Extension
- Tự động **tắt mic và camera** khi vào Google Meet (pre-join + in-meeting)
- Phát hiện tab Meet mở/đóng trong vòng < 1 giây
- Badge trên menu bar app hiển thị trạng thái kết nối realtime

### HUD Overlay
- Hiển thị trạng thái mic khi toggle (tự ẩn sau 2.5 giây)
- Hiển thị volume bar khi thay đổi âm lượng

---

## API Endpoints

Server chạy tại `http://<MAC_IP>:8765`

### Microphone

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| `POST` | `/toggle-mic` | Toggle mic, chờ Extension xác nhận (timeout 3s) |
| `POST` | `/toggle-mic/fast` | Toggle mic ngay, không chờ xác nhận |
| `GET`  | `/status` | Trạng thái mic và volume hiện tại |

### Volume

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| `POST` | `/volume/increase` | Tăng volume 10% |
| `POST` | `/volume/decrease` | Giảm volume 10% |
| `POST` | `/volume/set` | Đặt volume theo JSON `{"volume": 0.5}` |
| `POST` | `/volume/percent/:value` | Đặt volume theo path (hỗ trợ dấu phẩy: `0,375`) |
| `POST` | `/volume/toggle-mute` | Toggle mute speaker |
| `GET`  | `/volume/status` | Trạng thái volume hiện tại |

### Ví dụ

```bash
# Toggle mic (chờ Meet xác nhận)
curl -X POST http://192.168.1.10:8765/toggle-mic

# Đặt volume 40%
curl -X POST http://192.168.1.10:8765/volume/percent/0.4

# Kiểm tra trạng thái
curl http://192.168.1.10:8765/status
```

### Response format

```json
{
  "status": "ok",
  "muted": true,
  "confirmed": true,
  "source": "extension"
}
```

- `confirmed: true` — Chrome Extension đã xác nhận Meet thực sự muted
- `confirmed: false` — Không có tab Meet hoặc Extension timeout (mic vẫn toggle locally)

---

## Yêu cầu

- **macOS**: 13.0 Ventura trở lên
- **Browser**: Google Chrome hoặc Chromium
- **Mạng**: iPhone và Mac cùng Wi-Fi

---

## Troubleshooting

**App bị chặn khi mở lần đầu**
```bash
xattr -c /Applications/MicDrop.app
```

**Extension không kết nối với app**
- Kiểm tra app đang chạy (có icon trên menu bar)
- Reload extension tại `chrome://extensions`
- Xem log tại Settings → Connection Log trong app

**iOS Shortcut luôn báo cùng một trạng thái**
- Đảm bảo bước "Get Contents of URL" dùng method `POST`
- So sánh Text với `"true"` (không phải `"1"`)

**Volume không thay đổi**
- App cần quyền Accessibility: `System Settings → Privacy & Security → Accessibility`
