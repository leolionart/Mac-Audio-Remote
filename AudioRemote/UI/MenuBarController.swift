import Cocoa
import Combine
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
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

        setupPopover()
        setupStatusItem()
        updateIcon()
        observeStateChanges()
    }

    // MARK: - Setup

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let popoverView = MenuBarPopoverView(
            audioManager: audioManager,
            settingsManager: settingsManager,
            openSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettings()
            },
            quit: { [weak self] in
                self?.quit()
            }
        )

        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func observeStateChanges() {
        // Observe mic state changes
        audioManager.$isMuted
            .sink { [weak self] _ in
                self?.updateIcon()
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

    // MARK: - Actions

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate app to ensure popover gets focus
                NSApp.activate(ignoringOtherApps: true)
            }
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
