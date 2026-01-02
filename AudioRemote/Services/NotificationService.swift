import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private var isAuthorized = false

    private init() {
        requestAuthorization()
    }

    // MARK: - Public Methods

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted")
                self.isAuthorized = true
            } else {
                print("Notification permission denied")
                self.isAuthorized = false
            }
        }
    }

    func show(title: String, body: String, subtitle: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil = show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification sent: \(title)")
            }
        }
    }

    func showMicToggle(isMuted: Bool, source: String = "Menu Bar") {
        let title = isMuted ? "🔇 Microphone Muted" : "🎤 Microphone Unmuted"
        let body = "Toggled from \(source)"
        show(title: title, body: body)
    }

    func showVolumeChange(volume: Float, source: String = "Remote") {
        let volumePercent = Int(volume * 100)
        let title = "🔊 Volume"
        let body = "\(volumePercent)% - Changed from \(source)"
        show(title: title, body: body)
    }

    func showVolumeMute(isMuted: Bool, source: String = "Remote") {
        let title = isMuted ? "🔇 Volume Muted" : "🔊 Volume Unmuted"
        let body = "Toggled from \(source)"
        show(title: title, body: body)
    }

    func showUpdateAvailable(version: String) {
        show(title: "🎉 Update Available", body: "Version \(version) is now available. Open Settings to update.")
    }

    func showInfo(message: String) {
        show(title: "ℹ️ Audio Remote", body: message)
    }
}
