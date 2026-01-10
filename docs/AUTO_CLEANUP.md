# Auto-Cleanup Feature

## Tổng Quan

Tính năng auto-cleanup tự động phát hiện và dọn dẹp các instance cũ của AudioRemote đang chiếm cổng HTTP, giúp tránh lỗi "port already in use" khi khởi động app.

## Cách Hoạt Động

Khi HTTPServer khởi động:

1. **Kiểm tra port** - Xác định xem cổng 8765 (mặc định) có đang được sử dụng không
2. **Phát hiện process** - Nếu port đang bị chiếm, sử dụng `lsof` để tìm PID và tên process
3. **Xác minh ownership** - Chỉ kill nếu process là AudioRemote (an toàn, không kill app khác)
4. **Cleanup** - Gửi SIGKILL (-9) đến process cũ
5. **Chờ giải phóng** - Đợi tối đa 4 giây để port được giải phóng
6. **Khởi động** - Tiếp tục khởi động HTTP server nếu cleanup thành công

## Code Locations

- **NetworkService.swift**:
  - `getProcessUsingPort(port:)` - Lấy thông tin process đang sử dụng port
  - `killAudioRemoteOnPort(port:)` - Kill AudioRemote instance cũ

- **HTTPServer.swift**:
  - `start(port:)` - Tự động gọi auto-cleanup khi phát hiện port conflict

## Logs

Tính năng sử dụng `NSLog` để ghi logs vào system Console, có thể xem bằng:

```bash
# Xem logs realtime
log stream --predicate 'processImagePath contains "AudioRemote"'

# Xem logs gần đây
log show --predicate 'processImagePath contains "AudioRemote"' --last 1m
```

Ví dụ logs khi auto-cleanup hoạt động:

```
[HTTPServer] Starting on port 8765
[HTTPServer] Port 8765 not available, attempting auto-cleanup
🔄 Found old AudioRemote instance (PID: 3071) using port 8765. Cleaning up...
✅ Successfully cleaned up old instance. Port 8765 is now available.
[HTTPServer] Auto-cleanup successful
[HTTPServer] Port 8765 is available
```

## Lợi Ích

✅ **Không cần can thiệp thủ công** - Tự động xử lý port conflicts
✅ **An toàn** - Chỉ kill AudioRemote, không ảnh hưởng app khác
✅ **Nhanh chóng** - Cleanup và restart trong ~2-4 giây
✅ **Logging rõ ràng** - Dễ dàng debug qua system logs

## Edge Cases

- **Port bị chiếm bởi app khác**: Auto-cleanup sẽ từ chối kill và throw error với thông báo rõ ràng
- **Cleanup thất bại**: Sau 4 giây timeout, sẽ throw error thay vì cố gắng start
- **Multiple attempts**: Nếu cleanup thành công nhưng port vẫn bị chiếm, sẽ retry check port 10 lần với delay 200ms

## Testing

Chạy test script để verify tính năng:

```bash
# Manual test
.build/release/AudioRemote &  # Start first instance
.build/release/AudioRemote    # Start second (triggers auto-cleanup)

# Verify in logs
log show --predicate 'processImagePath contains "AudioRemote"' --last 30s | grep cleanup
```

## Version

Tính năng được thêm vào trong phiên bản development sau v2.8.4.
