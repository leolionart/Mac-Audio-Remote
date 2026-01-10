import Foundation
import Combine

/// Mute strategy for microphone
enum MuteMode: String, Codable, CaseIterable {
    case volumeZero     // Set volume to 0 (may not block all apps)
    case hardwareMute   // Use hardware mute property (recommended)
    case deviceSwitch   // Switch to null device (requires BlackHole)

    var displayName: String {
        switch self {
        case .volumeZero:
            return "Volume (may not block all apps)"
        case .hardwareMute:
            return "Hardware Mute (recommended)"
        case .deviceSwitch:
            return "Device Switch (requires BlackHole)"
        }
    }
}

struct AppSettings: Codable {
    var autoStart: Bool = false
    var httpServerEnabled: Bool = true
    var httpPort: Int = 8765
    var requestCount: Int = 0
    var volumeStep: Float = 0.1 // Volume change step (0.0-1.0), default 10%

    // Mute mode settings
    var muteMode: MuteMode = .hardwareMute
    var nullDeviceUID: String? = nil      // UID of virtual silent device (e.g., BlackHole)
    var realMicDeviceUID: String? = nil   // UID of real microphone (saved for restore)
    var forceChannelMute: Bool = true     // Force mute all channels on null device
}

class SettingsManager: ObservableObject {
    @Published var settings = AppSettings()

    private let defaults = UserDefaults.standard
    private let settingsKey = "app.settings.v2"
    private let legacyPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mic-toggle-server/settings.json")

    init() {
        load()
        migrateFromLegacyIfNeeded()
    }

    // MARK: - Public Methods

    func load() {
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
            print("Settings loaded from UserDefaults")
        } else {
            print("Using default settings")
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
            defaults.synchronize()
            print("Settings saved")
        }
    }

    func incrementRequestCount() {
        settings.requestCount += 1
        save()
    }

    // MARK: - Legacy Migration

    private func migrateFromLegacyIfNeeded() {
        // Check if already migrated
        if defaults.bool(forKey: "migrated_from_python") {
            print("Already migrated from Python app")
            return
        }

        // Check if legacy settings file exists
        guard FileManager.default.fileExists(atPath: legacyPath.path) else {
            print("No legacy settings file found")
            return
        }

        do {
            let data = try Data(contentsOf: legacyPath)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Found legacy settings file, migrating...")

                // Migrate settings
                if let autoStart = json["auto_start"] as? Bool {
                    settings.autoStart = autoStart
                }

                if let remoteAccess = json["remote_access"] as? Bool {
                    settings.httpServerEnabled = remoteAccess
                }

                if let requestCount = json["request_count"] as? Int {
                    settings.requestCount = requestCount
                }

                // Save migrated settings
                save()

                // Mark as migrated
                defaults.set(true, forKey: "migrated_from_python")
                defaults.synchronize()

                print("Successfully migrated settings from Python app:")
                print("  - Auto-start: \(settings.autoStart)")
                print("  - HTTP Server: \(settings.httpServerEnabled)")
                print("  - Request count: \(settings.requestCount)")
            }
        } catch {
            print("Error migrating legacy settings: \(error)")
        }
    }
}
