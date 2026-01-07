import Foundation
import ServiceManagement

class AutoStartService {
    static let shared = AutoStartService()

    private init() {}

    // MARK: - Public Methods

    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        print("Auto-start already enabled")
                    } else {
                        try SMAppService.mainApp.register()
                        print("Auto-start enabled successfully")
                    }
                } else {
                    if SMAppService.mainApp.status == .notRegistered {
                        print("Auto-start already disabled")
                    } else {
                        try SMAppService.mainApp.unregister()
                        print("Auto-start disabled successfully")
                    }
                }
            } catch {
                print("Auto-start error: \(error.localizedDescription)")
            }
        } else {
            // Fallback for macOS 12 and below
            setEnabledLegacy(enabled)
        }
    }

    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return isEnabledLegacy()
        }
    }

    // MARK: - Legacy Support (macOS 12 and below)

    private func setEnabledLegacy(_ enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else {
            print("Cannot get bundle identifier for auto-start")
            return
        }

        if enabled {
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(Bundle.main.bundlePath)", hidden:false}
            end tell
            """
            _ = runAppleScript(script)
        } else {
            let script = """
            tell application "System Events"
                delete login item "AudioRemote"
            end tell
            """
            _ = runAppleScript(script)
        }
    }

    private func isEnabledLegacy() -> Bool {
        let script = """
        tell application "System Events"
            return name of every login item
        end tell
        """

        if let result = runAppleScript(script) {
            return result.contains("AudioRemote")
        }

        return false
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                print("AppleScript error: \(error)")
                return nil
            }

            return output.stringValue
        }

        return nil
    }
}
