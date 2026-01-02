import Cocoa
import Foundation
import Sparkle

// UpdateManager - Uses Sparkle framework for auto-updates
class UpdateManager: ObservableObject {
    @Published var canCheckForUpdates = true
    @Published var lastUpdateCheckDate: Date?

    private var updaterController: SPUStandardUpdaterController?
    private let feedURL = "https://leolionart.github.io/Mac-Audio-Remote/appcast.xml"

    init() {
        // Load last check date
        if let date = UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date {
            self.lastUpdateCheckDate = date
        }

        // Initialize Sparkle
        setupSparkle()
    }

    private func setupSparkle() {
        // Create updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        print("✅ Sparkle initialized successfully")
        print("📡 Feed URL will be read from Info.plist SUFeedURL key")
    }

    func checkForUpdates() {
        // Update last check date
        lastUpdateCheckDate = Date()
        UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate")

        // Trigger Sparkle update check
        updaterController?.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        // For free version, do nothing in background
        // Only manual check by opening browser
        print("Background update check - Free version: No action")
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            // Always false for free version
            return false
        }
        set {
            // Ignore - not supported in free version
            UserDefaults.standard.set(false, forKey: "automaticallyChecksForUpdates")
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            return false
        }
        set {
            // Ignore - not supported in free version
            UserDefaults.standard.set(false, forKey: "automaticallyDownloadsUpdates")
        }
    }
}
