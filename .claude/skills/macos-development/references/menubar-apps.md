# Menu Bar Apps Development

## Two Approaches

### Modern: MenuBarExtra (macOS 13+)
```swift
@main
struct MyApp: App {
    var body: some Scene {
        MenuBarExtra("App", systemImage: "star.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window) // .window for popover, .menu for dropdown
    }
}
```

### Traditional: NSStatusItem (All versions)
```swift
@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Hide dock icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 200)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
```

## Hiding Dock Icon

**Method 1: Programmatic**
```swift
NSApp.setActivationPolicy(.accessory)
```

**Method 2: Info.plist**
```xml
<key>LSUIElement</key>
<true/>
```

## Dynamic Icon Updates with Combine
```swift
class AppState: ObservableObject {
    @Published var isMuted: Bool = false
}

// In AppDelegate
var cancellables = Set<AnyCancellable>()

appState.$isMuted.sink { isMuted in
    let icon = isMuted ? "mic.slash.fill" : "mic.fill"
    self.statusItem?.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
}.store(in: &cancellables)
```

## SF Symbols Configuration
```swift
// Basic
button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
button.image?.isTemplate = true // Adapts to light/dark mode

// With configuration
let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
```

## NSMenu for Traditional Dropdown
```swift
let menu = NSMenu()
menu.addItem(NSMenuItem(title: "Toggle", action: #selector(toggle), keyEquivalent: "t"))
menu.addItem(NSMenuItem.separator())
menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
statusItem?.menu = menu
```

## Global Keyboard Shortcuts
Requires Accessibility permission in System Settings.

```swift
var monitor: Any?

func applicationDidFinishLaunching(_ notification: Notification) {
    monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        // Option + M (keyCode 46)
        if event.modifierFlags.contains(.option) && event.keyCode == 46 {
            self.handleHotkey()
        }
    }
}

func applicationWillTerminate(_ notification: Notification) {
    if let monitor = monitor {
        NSEvent.removeMonitor(monitor)
    }
}
```

### Common Key Codes
- M: 46
- Space: 49
- Return: 36
- Escape: 53

## SwiftUI-AppKit Integration
```swift
// Embed SwiftUI in NSPopover
popover.contentViewController = NSHostingController(rootView: MySwiftUIView())

// Embed SwiftUI in NSWindow
let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
window.title = "Settings"
window.makeKeyAndOrderFront(nil)
```

## Best Practices
1. Use `.transient` popover behavior for auto-close
2. Call `NSApp.activate(ignoringOtherApps: true)` when showing popover
3. Set `button.image?.isTemplate = true` for automatic dark mode support
4. Clean up monitors in `applicationWillTerminate`
5. Use Combine for reactive icon updates
