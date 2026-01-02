import Cocoa
// import Sparkle temporarily disabled for testing

class UpdateManager: ObservableObject {
    // private let updater: SPUUpdater
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    init() {
        // Initialize Sparkle updater - Temporarily disabled
        /*
        let hostBundle = Bundle.main
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        self.updater = updaterController.updater
        self.canCheckForUpdates = updater.canCheckForUpdates
        */

        // Load last check date
        if let date = UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date {
            self.lastUpdateCheckDate = date
        }
    }

    func checkForUpdates() {
        // updater.checkForUpdates()
        print("Manual update check requested (Sparkle not yet configured)")
        lastUpdateCheckDate = Date()
        UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate")
    }

    func checkForUpdatesInBackground() {
        // updater.checkForUpdatesInBackground()
        print("Background update check requested (Sparkle not yet configured)")
        lastUpdateCheckDate = Date()
        UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate")
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            // return updater.automaticallyChecksForUpdates
            return UserDefaults.standard.bool(forKey: "automaticallyChecksForUpdates")
        }
        set {
            // updater.automaticallyChecksForUpdates = newValue
            UserDefaults.standard.set(newValue, forKey: "automaticallyChecksForUpdates")
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            // return updater.automaticallyDownloadsUpdates
            return UserDefaults.standard.bool(forKey: "automaticallyDownloadsUpdates")
        }
        set {
            // updater.automaticallyDownloadsUpdates = newValue
            UserDefaults.standard.set(newValue, forKey: "automaticallyDownloadsUpdates")
        }
    }
}
