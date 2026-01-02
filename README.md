# 🎤 Audio Remote

> Native macOS menu bar app for controlling microphone and speaker audio from anywhere - including your iPhone via Shortcuts.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## ✨ Features

- 🎤 **Microphone Control** - Toggle mute/unmute with one click or keyboard shortcut (⌘M)
- 🔊 **Volume Control** - Adjust speaker volume, increase/decrease, or mute remotely
- 📱 **iOS Shortcuts Integration** - Control your Mac's audio from iPhone via HTTP webhooks
- 🌐 **Web Interface** - Modern web UI for remote control from any browser
- ⚡️ **Ultra-Fast** - ~1ms toggle latency using Core Audio API (50x faster than AppleScript)
- 🔔 **Smart Notifications** - Get notified when audio state changes
- 🚀 **Auto-start** - Launch automatically at login
- 💡 **Menu Bar Only** - Clean interface with no Dock icon

## 📦 Installation

### From Release (Recommended)

1. Download `AudioRemote.dmg` from [Releases](https://github.com/leolionart/Mac-Audio-Remote/releases)
2. Open the DMG and drag Audio Remote to Applications
3. Launch from Applications folder
4. Grant microphone permissions when prompted

### From Source

```bash
# Clone the repository
git clone https://github.com/leolionart/Mac-Audio-Remote.git
cd Mac-Audio-Remote

# Build and run
swift build -c release
.build/release/AudioRemote
```

**Note**: For unsigned apps, run `xattr -cr AudioRemote.app` to bypass Gatekeeper.

## 🚀 Quick Start

1. **Launch the app** - Look for the microphone icon in your menu bar
2. **Toggle microphone** - Click the icon or press ⌘M
3. **Enable remote control** - Open Settings → Enable HTTP Server
4. **Get your webhook URL** - Copy the URL shown in Settings (e.g., `http://192.168.1.100:8765`)

## 📱 iOS Shortcuts Setup

Control your Mac's audio from your iPhone:

1. Open Shortcuts app on iPhone
2. Create new shortcut
3. Add "Get Contents of URL" action
4. Paste your webhook URL (e.g., `http://192.168.1.100:8765/toggle-mic`)
5. Set method to **POST**
6. Add to Home Screen for instant access

**Pre-made Shortcuts**: Check the [`shortcuts/`](shortcuts/) folder for ready-to-use shortcuts for microphone toggle, volume control, and more.

For detailed instructions, see [iOS Shortcuts Guide](iOS-SHORTCUTS-GUIDE.md).

## 🎯 API Endpoints

Perfect for automation, Shortcuts, or custom integrations:

### Microphone Control
```bash
# Toggle microphone mute/unmute
curl -X POST http://localhost:8765/toggle-mic

# Get status
curl http://localhost:8765/status
```

### Volume Control
```bash
# Increase/decrease volume
curl -X POST http://localhost:8765/volume/increase
curl -X POST http://localhost:8765/volume/decrease

# Toggle speaker mute
curl -X POST http://localhost:8765/volume/toggle-mute

# Set specific volume (0.0 to 1.0)
curl -X POST http://localhost:8765/volume/set \
  -H "Content-Type: application/json" \
  -d '{"volume": 0.5}'

# Get volume status
curl http://localhost:8765/volume/status
```

### Web Interface
```bash
# Open interactive web UI
open http://localhost:8765
```

## ⚙️ Settings

Click the menu bar icon → Settings to configure:

- **Auto-start at Login** - Launch automatically when you log in
- **Notifications** - Get notified on audio state changes
- **HTTP Server** - Enable/disable remote control
- **Server Port** - Change HTTP server port (default: 8765)
- **Statistics** - View total toggle count

## 🛠️ Technical Highlights

Built with modern macOS technologies:

- **Core Audio API** - Direct hardware control for ultra-low latency
- **Swift & SwiftUI** - Native performance and modern UI
- **Vapor Framework** - Robust HTTP server for remote control
- **Combine** - Reactive state management
- **SMAppService** - Native auto-start support (macOS 13+)

### Performance Comparison

| Metric | Previous Version | Audio Remote | Improvement |
|--------|-----------------|--------------|-------------|
| Toggle Latency | ~50ms | ~1ms | **50x faster** |
| Memory Usage | ~100MB | ~20MB | **80% less** |
| Status Updates | 10s polling | Event-driven | **Instant** |

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- Microphone permission (grant in System Settings → Privacy & Security)

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs or request features via [Issues](https://github.com/leolionart/Mac-Audio-Remote/issues)
- Submit pull requests
- Improve documentation

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 🙏 Credits

- Built with [Vapor](https://vapor.codes) framework
- Icons from SF Symbols
- Inspired by the need for simple, fast audio control

---

**Made with ❤️ for macOS users who want instant audio control**
