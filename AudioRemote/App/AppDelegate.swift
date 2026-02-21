import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var bridgeManager: BridgeManager!
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
        bridgeManager = BridgeManager.shared
        settingsManager = SettingsManager()

        // Initialize update manager
        updateManager = UpdateManager()

        // Initialize HTTP server early so MenuBarController can reference it
        httpServer = HTTPServer(
            bridgeManager: bridgeManager,
            settingsManager: settingsManager
        )

        // Setup menu bar
        menuBarController = MenuBarController(
            bridgeManager: bridgeManager,
            settingsManager: settingsManager,
            updateManager: updateManager,
            httpServer: httpServer
        )

        // Setup global hotkey (Option+M)
        globalHotkeyManager = GlobalHotkeyManager(
            bridgeManager: bridgeManager,
            settingsManager: settingsManager
        )

        // Start HTTP server if enabled
        if settingsManager.settings.httpServerEnabled {
            startHTTPServer()
        }

        // Observe settings changes to restart/stop server
        // dropFirst() skips the initial emission from @Published to prevent double-start
        settingsManager.$settings
            .dropFirst()
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
        print("Mic status: \(bridgeManager.isMuted ? "Muted" : "Active")")
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
                    alert.informativeText = "Failed to start HTTP server on port \(self.settingsManager.settings.httpPort).\n\nThis usually happens after an update when the old version is still holding the port.\n\nOpen Settings → click \"Restart\" to retry after a few seconds."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open Settings")
                    alert.addButton(withTitle: "Dismiss")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        self.menuBarController?.openSettings()
                    }
                    // Don't disable the setting - let user retry via Restart button in Settings
                }
            }
        }
    }
}
