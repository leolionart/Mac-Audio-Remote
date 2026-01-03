# 🎤 Audio Remote

Native macOS menu bar app for controlling microphone and speaker audio from your iPhone via Shortcuts.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- 🎤 Toggle microphone on/off with keyboard shortcut (⌘M)
- 🔊 Control speaker volume (increase/decrease/mute)
- 📱 iOS Shortcuts integration via HTTP webhooks
- 🌐 Web interface for remote control
- ⚡️ Ultra-fast ~1ms toggle latency
- 🔔 Smart notifications
- 🚀 Auto-start at login

![Audio Remote Demo](https://cdn-std.droplr.net/files/acc_692205/Mixpfi)

## Installation

1. Download `AudioRemote.dmg` from [Releases](https://github.com/leolionart/Mac-Audio-Remote/releases)
2. Open the DMG and drag Audio Remote to Applications
3. Launch and grant microphone permissions when prompted
4. Look for the microphone icon in your menu bar

**For unsigned apps**: Run `xattr -cr /Applications/AudioRemote.app` if macOS blocks it.

## Quick Setup

### Enable Remote Control

1. Click menu bar icon → **Settings**
2. Enable **HTTP Server**
3. Note your webhook URL (e.g., `http://192.168.1.100:8765`)

### iOS Shortcuts

1. Open **Shortcuts** app on iPhone
2. Create new shortcut
3. Add **"Get Contents of URL"** action
4. Paste webhook URL: `http://YOUR_MAC_IP:8765/toggle-mic`
5. Set method to **POST**
6. Add to Home Screen

**Pre-made shortcuts**: Download from [`shortcuts/`](shortcuts/) folder.

## API Endpoints

```bash
# Microphone
curl -X POST http://localhost:8765/toggle-mic
curl http://localhost:8765/status

# Volume
curl -X POST http://localhost:8765/volume/increase
curl -X POST http://localhost:8765/volume/decrease
curl -X POST http://localhost:8765/volume/toggle-mute

# Set volume (0.0 to 1.0)
curl -X POST http://localhost:8765/volume/set \
  -H "Content-Type: application/json" \
  -d '{"volume": 0.5}'

# Web UI
open http://localhost:8765
```

## Requirements

- macOS 13.0 (Ventura) or later
- Microphone permission in System Settings

## Support

- [Issues](https://github.com/leolionart/Mac-Audio-Remote/issues) - Report bugs or request features
- [iOS Shortcuts Guide](iOS-SHORTCUTS-GUIDE.md) - Detailed setup instructions

## License

MIT License - See [LICENSE](LICENSE)

---

**Made with ❤️ for macOS users**
