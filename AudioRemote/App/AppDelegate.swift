import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var audioManager: AudioManager!
    var settingsManager: SettingsManager!
    var menuBarController: MenuBarController!
    var httpServer: HTTPServer!
    var globalHotkeyManager: GlobalHotkeyManager!
    var updateManager: UpdateManager!
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (app is menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize managers
        audioManager = AudioManager()
        settingsManager = SettingsManager()

        // Sync settings to AudioManager
        syncSettingsToAudioManager()

        // Request notification permission
        NotificationService.shared.requestAuthorization()

        // Initialize update manager
        updateManager = UpdateManager()

        // Setup menu bar
        menuBarController = MenuBarController(
            audioManager: audioManager,
            settingsManager: settingsManager,
            updateManager: updateManager
        )

        // Initialize HTTP server
        httpServer = HTTPServer(
            audioManager: audioManager,
            settingsManager: settingsManager
        )

        // Setup global hotkey (Option+M)
        globalHotkeyManager = GlobalHotkeyManager(
            audioManager: audioManager,
            settingsManager: settingsManager
        )

        // Start HTTP server if enabled
        if settingsManager.settings.httpServerEnabled {
            startHTTPServer()
        }

        // Observe settings changes to restart/stop server
        settingsManager.$settings
            .sink { [weak self] settings in
                guard let self = self else { return }

                if settings.httpServerEnabled {
                    self.startHTTPServer()
                } else {
                    // Stop server asynchronously
                    Task {
                        await self.httpServer.stop()
                    }
                }
            }
            .store(in: &cancellables)

        // Check if we should reopen settings after update
        if UserDefaults.standard.bool(forKey: "audioremote.reopenSettings") {
            UserDefaults.standard.removeObject(forKey: "audioremote.reopenSettings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.menuBarController?.openSettings()
            }
        }

        print("Audio Remote started successfully")
        print("Mic status: \(audioManager.isMuted ? "Muted" : "Active")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop HTTP server gracefully
        Task {
            await httpServer?.stop()
        }
        print("Audio Remote terminated")
    }

    // MARK: - Private Methods

    private func startHTTPServer() {
        Task {
            do {
                try await httpServer.start(port: settingsManager.settings.httpPort)
            } catch {
                print("Failed to start HTTP server: \(error)")

                // Show error alert
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "HTTP Server Error"
                    alert.informativeText = "Failed to start HTTP server on port \(self.settingsManager.settings.httpPort).\n\nError: \(error.localizedDescription)\n\nPlease check if another application is using this port."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()

                    // Disable HTTP server in settings
                    self.settingsManager.settings.httpServerEnabled = false
                    self.settingsManager.save()
                }
            }
        }
    }

    /// Sync settings from SettingsManager to AudioManager
    private func syncSettingsToAudioManager() {
        audioManager.muteMode = settingsManager.settings.muteMode
        audioManager.nullDeviceUID = settingsManager.settings.nullDeviceUID
        audioManager.realMicDeviceUID = settingsManager.settings.realMicDeviceUID

        print("Synced settings to AudioManager:")
        print("  - Mute mode: \(settingsManager.settings.muteMode.rawValue)")
        print("  - Null device UID: \(settingsManager.settings.nullDeviceUID ?? "not set")")
        print("  - Real mic UID: \(settingsManager.settings.realMicDeviceUID ?? "not set")")
    }
}
