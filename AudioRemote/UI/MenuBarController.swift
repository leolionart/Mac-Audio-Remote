import Cocoa
import Combine
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let audioManager: AudioManager
    private let settingsManager: SettingsManager
    private let updateManager: UpdateManager
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    init(audioManager: AudioManager, settingsManager: SettingsManager, updateManager: UpdateManager) {
        self.audioManager = audioManager
        self.settingsManager = settingsManager
        self.updateManager = updateManager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupMenu()
        updateIcon()
        observeStateChanges()
    }

    // MARK: - Setup

    private func setupMenu() {
        menu = NSMenu()

        // Status display (read-only)
        let statusMenuItem = NSMenuItem(
            title: audioManager.isMuted ? "Microphone: Muted" : "Microphone: Active",
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100 // Tag for updating later
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle action
        let toggleMenuItem = NSMenuItem(
            title: "Toggle Microphone",
            action: #selector(toggleMic),
            keyEquivalent: "m"
        )
        toggleMenuItem.keyEquivalentModifierMask = .option
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsMenuItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)

        // Open System Sound Preferences
        let soundPrefsMenuItem = NSMenuItem(
            title: "Open Sound Preferences...",
            action: #selector(openSoundPreferences),
            keyEquivalent: ""
        )
        soundPrefsMenuItem.target = self
        menu.addItem(soundPrefsMenuItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutMenuItem = NSMenuItem(
            title: "About Audio Remote",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitMenuItem = NSMenuItem(
            title: "Quit Audio Remote",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    private func observeStateChanges() {
        // Observe mic state changes
        audioManager.$isMuted
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateStatusText()
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        if let button = statusItem.button {
            // Use SF Symbols mic icons for mute/unmute state
            let iconName = audioManager.isMuted ? "mic.slash.fill" : "mic.fill"
            button.image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: audioManager.isMuted ? "Microphone Muted" : "Microphone Active"
            )
            button.image?.isTemplate = true
        }
    }

    private func updateStatusText() {
        if let statusItem = menu.item(withTag: 100) {
            statusItem.title = audioManager.isMuted ? "Microphone: Muted" : "Microphone: Active"
        }
    }

    // MARK: - Actions

    @objc private func toggleMic() {
        let muted = audioManager.toggle()
        settingsManager.incrementRequestCount()

        // Show notification if enabled
        if settingsManager.settings.notificationsEnabled {
            NotificationService.shared.showMicToggle(isMuted: muted, source: "Menu Bar")
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                settingsManager: settingsManager,
                audioManager: audioManager,
                updateManager: updateManager
            )

            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Audio Remote Settings"
            window.setContentSize(NSSize(width: 600, height: 500))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSoundPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "Audio Remote"
        alert.informativeText = """
        Version 2.0.0

        A native macOS menu bar app to control audio input/output remotely.

        Features:
        • Menu bar status indicator
        • Microphone mute/unmute control
        • Output volume control
        • Keyboard shortcuts
        • iOS Shortcuts webhook support
        • Auto-start at login
        • Native Swift implementation

        Created with ❤️ using Swift
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
