# Hướng Dẫn Release

## Cách Tạo Release Tự Động

Repository này đã được cấu hình với GitHub Actions để tự động build và release app macOS.

### Bước 1: Tạo Version Tag

Để tạo một release mới, chỉ cần tạo và push một git tag với format `v*.*.*`:

```bash
# Ví dụ: Release version 1.0.0
git tag v1.0.0
git push origin v1.0.0
```

### Bước 2: GitHub Actions Tự Động Chạy

Khi bạn push tag, GitHub Actions sẽ tự động:

1. ✅ Build app ở chế độ release
2. ✅ Tạo file `.app` bundle
3. ✅ Đóng gói thành file `.dmg` (installer cho macOS)
4. ✅ Tạo file `.zip` (alternative download)
5. ✅ Tạo GitHub Release với các file đính kèm
6. ✅ Tự động sinh release notes

### Bước 3: Download từ GitHub Releases

Sau khi workflow hoàn thành (khoảng 5-10 phút), bạn có thể:

- Vào trang Releases: https://github.com/leolionart/Mac-Audio-Remote/releases
- Download file `AudioRemote.dmg` hoặc `AudioRemote.zip`
- Chia sẻ link release cho người dùng

## Manual Build (Không Dùng GitHub Actions)

Nếu muốn build thủ công trên máy local:

```bash
# Build release binary
swift build -c release

# Chạy script build app
./build-app.sh

# File AudioRemote.app sẽ được tạo trong thư mục hiện tại
```

## Version Numbering

Sử dụng [Semantic Versioning](https://semver.org/):

- `v1.0.0` - Major release (breaking changes)
- `v1.1.0` - Minor release (new features)
- `v1.0.1` - Patch release (bug fixes)

## Workflows

### `release.yml`
- **Trigger**: Khi push tag `v*.*.*` hoặc manual trigger
- **Mục đích**: Build và tạo GitHub Release
- **Output**: `.dmg` và `.zip` files

### `ci.yml`
- **Trigger**: Push hoặc PR vào `main` hoặc `develop` branch
- **Mục đích**: Kiểm tra code build được không
- **Output**: Không có artifacts, chỉ validate

## Ví Dụ Release Flow

```bash
# 1. Commit các thay đổi
git add .
git commit -m "Add new feature: XYZ"
git push origin main

# 2. Tạo tag cho release
git tag v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0

# 3. Đợi GitHub Actions build (5-10 phút)
# 4. Check https://github.com/leolionart/Mac-Audio-Remote/releases
```

## Troubleshooting

### Workflow Failed?

1. Kiểm tra logs tại: `Actions` tab trên GitHub
2. Đảm bảo `Package.resolved` không bị lỗi
3. Kiểm tra `Info.plist` và `AppIcon.icns` tồn tại

### Muốn Test Build Trước Khi Release?

1. Vào tab `Actions` trên GitHub
2. Chọn workflow `Build and Release macOS App`
3. Click `Run workflow` → Chọn branch `main`
4. Artifacts sẽ được upload (không tạo Release)
