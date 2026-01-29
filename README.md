# 🎤 MicDrop (Chrome Extension Edition)

A hybrid macOS app + Chrome Extension system to control Google Meet microphone remotely (from global keyboard shortcut ⌥M or iOS Shortcuts).

![Architecture](https://img.shields.io/badge/Architecture-Hybrid-blue.svg)
![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Chrome](https://img.shields.io/badge/Chrome-Extension-orange.svg)

## How it works

1. **macOS App**: Runs a local HTTP bridge server and listens for Global Hotkey (⌥M).
2. **Chrome Extension**: Connects to the app via local HTTP bridge and controls Google Meet UI directly.
3. **iOS Shortcuts**: Sends HTTP requests to the macOS App, which forwards them to Chrome.

## Installation

### Step 1: Install macOS App
1. Build the app using Xcode or Swift:
   ```bash
   swift build -c release
   ```
2. Run the app. It will start a local server at port 8765.

### Step 2: Install Chrome Extension
1. Open Chrome and go to `chrome://extensions`.
2. Enable **Developer mode** (top right).
3. Click **Load unpacked**.
4. Select the `chrome-extension` folder from this project.
5. Open Google Meet and grant permissions if asked.

## Usage

- **Toggle Mic**: Press `Option + M` (works globally, even if Chrome is backgrounded).
- **iOS Control**: Use Shortcuts to call `http://YOUR_MAC_IP:8765/toggle-mic`.
- **Status**: Check the menu bar icon or Extension popup.

## API Endpoints (For iOS Shortcuts)

Same as before, backward compatible:

```bash
# Toggle Microphone (Google Meet)
curl -X POST http://localhost:8765/toggle-mic

# Volume Control (System Speaker)
curl -X POST http://localhost:8765/volume/increase
curl -X POST http://localhost:8765/volume/decrease
```

## Requirements
- macOS 13.0+
- Google Chrome (or Chromium-based browser)
