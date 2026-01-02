# 🎛️ Audio Remote - macOS Audio Control

Control your Mac's microphone and speaker volume remotely via HTTP webhooks, perfect for iOS Shortcuts integration.

## ✨ Features

### Core Features
- 🎤 **Microphone Control**: Toggle mute/unmute
- 🔊 **Volume Control**: Increase, decrease, set exact volume, toggle mute
- ⌨️ **Keyboard Shortcut**: Option+M to toggle microphone
- 📱 **iOS Shortcuts Support**: Pre-built templates included
- 🔄 **Auto-Restart**: HTTP server auto-recovers from errors
- 🚀 **Performance**: ~1ms toggle latency (50x faster than Python)

### Technical Highlights
- **Native Swift**: Built with Core Audio API for direct hardware access
- **Async HTTP Server**: Vapor framework with non-blocking I/O
- **Menu Bar App**: Runs in background, no dock icon
- **Auto-Start**: Optional launch at login
- **Settings UI**: SwiftUI-based configuration interface
- **Configurable**: Customizable volume step (default 10%)

## 🚀 Quick Start

### Installation

1. **Download** `AudioRemote.app` from releases
2. **Move** to `/Applications`
3. **First Launch**: Right-click → Open (to bypass Gatekeeper)
4. **Grant Permissions**: Allow microphone access in System Settings

### First Run

1. Look for 🎤 icon in menu bar
2. Click icon → **Settings...**
3. Note your **Local IP** in Network Info section
4. All webhook URLs are displayed in Settings

## 📱 iOS Shortcuts Setup

### Quick Import

1. Transfer `.shortcut` files from `shortcuts/` folder to your iPhone via AirDrop
2. Open each file on iPhone
3. Replace `YOUR_MAC_IP` with your Mac's IP address
4. Add shortcuts to Home Screen or Widgets

### Available Shortcuts

- **Toggle-Mic.shortcut** - Toggle microphone on/off
- **Volume-Up.shortcut** - Increase volume by 10%
- **Volume-Down.shortcut** - Decrease volume by 10%
- **Toggle-Mute.shortcut** - Mute/unmute speaker

See [iOS-SHORTCUTS-GUIDE.md](iOS-SHORTCUTS-GUIDE.md) for detailed setup instructions.

## 🔗 API Endpoints

### Microphone Control

```bash
# Toggle microphone
curl -X POST http://YOUR_MAC_IP:8765/toggle-mic

# Get microphone status
curl http://YOUR_MAC_IP:8765/status
# Response: {"muted": false, "outputVolume": 0.5, "outputMuted": false}
```

### Volume Control

```bash
# Increase volume (+10%)
curl -X POST http://YOUR_MAC_IP:8765/volume/increase

# Decrease volume (-10%)
curl -X POST http://YOUR_MAC_IP:8765/volume/decrease

# Set exact volume (0.0 - 1.0)
curl -X POST http://YOUR_MAC_IP:8765/volume/set \
  -H "Content-Type: application/json" \
  -d '{"volume": 0.75}'

# Toggle volume mute
curl -X POST http://YOUR_MAC_IP:8765/volume/toggle-mute

# Get volume status
curl http://YOUR_MAC_IP:8765/volume/status
# Response: {"status": "ok", "volume": 0.5, "muted": false}
```

### Web Interface

Open `http://YOUR_MAC_IP:8765` in any browser for interactive control panel.

## ⚙️ Settings

Access settings via menu bar icon → **Settings...**

### Webhook URLs Display

Settings window shows all available endpoints organized by category:
- **Microphone**: Toggle Mic, Mic Status
- **Volume**: Vol Up, Vol Down, Toggle Mute, Vol Status
- One-click copy to clipboard for each URL

## 🎨 Menu Bar Features

- **Icon Indicator**: Shows current mic state (mic / mic.slash)
- **Quick Toggle**: Option+M keyboard shortcut
- **Settings Access**: Click icon → Settings...

## 🔧 Development

### Build from Source

```bash
# Build and create .app bundle
./build-app.sh

# Run directly
.build/release/AudioRemote
```

See [CLAUDE.md](CLAUDE.md) for detailed development guide.

## 📖 Documentation

- [iOS Shortcuts Guide](iOS-SHORTCUTS-GUIDE.md) - Detailed shortcut setup
- [Features](FEATURES.md) - Auto-restart & configurable volume step
- [CLAUDE.md](CLAUDE.md) - Development guide

## 🆘 Troubleshooting

### App won't open
```bash
xattr -cr AudioRemote.app
```

### Port in use
```bash
lsof -ti :8765 | xargs kill -9
```

### Shortcuts not working
1. Verify same Wi-Fi network
2. Check HTTP Server enabled in Settings
3. Test: `http://YOUR_MAC_IP:8765`

## 📄 License

MIT License

---

**Made with ❤️ using Swift**
