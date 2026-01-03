import Cocoa
import Foundation
import Sparkle

// UpdateManager - Uses Sparkle framework for auto-updates
class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var isCheckingForUpdates = false

    private var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()

        // Load last check date
        if let date = UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date {
            self.lastUpdateCheckDate = date
        }

        // Initialize Sparkle
        setupSparkle()
    }

    private func setupSparkle() {
        // Create updater controller with self as delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Bind canCheckForUpdates to the updater's property
        if let updater = updaterController?.updater {
            canCheckForUpdates = updater.canCheckForUpdates

            // Observe changes to canCheckForUpdates
            updater.publisher(for: \.canCheckForUpdates)
                .receive(on: DispatchQueue.main)
                .assign(to: &$canCheckForUpdates)
        }

        print("✅ Sparkle initialized successfully")
        if let feedURL = updaterController?.updater.feedURL {
            print("📡 Feed URL: \(feedURL)")
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            print("⚠️ Cannot check for updates right now")
            return
        }

        isCheckingForUpdates = true

        // Update last check date
        lastUpdateCheckDate = Date()
        UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate")

        // Trigger Sparkle update check - this will show Sparkle's UI
        updaterController?.checkForUpdates(nil)

        // Reset checking state after a delay (Sparkle handles the rest)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isCheckingForUpdates = false
        }
    }

    func checkForUpdatesInBackground() {
        updaterController?.updater.checkForUpdatesInBackground()
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("✅ Loaded appcast with \(appcast.items.count) items")
        for item in appcast.items {
            print("  - Version: \(item.displayVersionString ?? "unknown") (build \(item.versionString ?? "?"))")
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        print("ℹ️ No update available: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("🎉 Update available: \(item.displayVersionString ?? "unknown")")
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        print("❌ Update aborted: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
        }
    }
}
