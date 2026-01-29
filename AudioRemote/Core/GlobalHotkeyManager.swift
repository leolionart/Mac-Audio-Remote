import Cocoa
import Carbon

class GlobalHotkeyManager {
    private let bridgeManager: BridgeManager
    private let settingsManager: SettingsManager
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(bridgeManager: BridgeManager, settingsManager: SettingsManager) {
        self.bridgeManager = bridgeManager
        self.settingsManager = settingsManager

        registerGlobalHotKey()
    }

    private func registerGlobalHotKey() {
        // Option+M keyboard shortcut
        let keyCode: UInt32 = 46 // 'M' key
        let modifiers: UInt32 = UInt32(optionKey) // Option key

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("HTKE".fourCharCodeValue)
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Create callback handler
        let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKeyPress()

            return noErr
        }

        // Install event handler
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        // Register hot key
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("Global hotkey registered: Option+M")
    }

    private func handleHotKeyPress() {
        let muted = bridgeManager.toggle()
        settingsManager.incrementRequestCount()

        // Show HUD overlay on main thread
        DispatchQueue.main.async {
            MicrophoneHUDController.shared.show(isMuted: muted)
        }
    }

    deinit {
        // Unregister hot key
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        // Remove event handler
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

// Helper extension for FourCharCode conversion
private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
