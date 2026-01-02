import SwiftUI

@main
struct AudioRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // SwiftUI scene for settings window (opened via menu bar)
        Settings {
            EmptyView()
        }
    }
}
