import SwiftUI
import AppKit

class WarningHUDWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }
}

struct WarningHUDView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.orange)

            // Title
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)

            // Message
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .shadow(color: .black.opacity(0.3), radius: 10)
        )
        .fixedSize()
    }
}

@MainActor
class WarningHUDController: ObservableObject {
    static let shared = WarningHUDController()

    private var window: WarningHUDWindow?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(icon: String, title: String, message: String) {
        NSLog("⚠️ WarningHUD: Showing warning - \(title)")

        // Cancel any existing hide task
        hideTask?.cancel()

        // Create or update window
        if window == nil {
            window = WarningHUDWindow()
            NSLog("⚠️ WarningHUD: Created new window")
        }

        let contentView = WarningHUDView(icon: icon, title: title, message: message)
        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView

        // Force proper sizing
        hostingView.invalidateIntrinsicContentSize()
        let fittingSize = hostingView.fittingSize
        window?.setContentSize(fittingSize)

        NSLog("⚠️ WarningHUD: Window size: \(fittingSize)")

        // Center window on screen
        if let screen = NSScreen.main, let window = window {
            let screenFrame = screen.frame
            let x = (screenFrame.width - fittingSize.width) / 2
            let y = (screenFrame.height - fittingSize.height) / 2 + 150 // Slightly higher than mic HUD
            window.setFrameOrigin(NSPoint(x: x, y: y))
            NSLog("⚠️ WarningHUD: Window position: (\(x), \(y))")
        }

        // Show window with fade in
        window?.alphaValue = 0
        window?.orderFrontRegardless()

        NSLog("⚠️ WarningHUD: Window ordered front, isVisible: \(window?.isVisible ?? false)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1.0
        }

        // Auto-hide after 3 seconds (longer than mic HUD for warnings)
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            hide()
        }
    }

    @MainActor
    func hide() {
        hideTask?.cancel()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.window?.orderOut(nil)
            }
        })
    }

    deinit {
        hideTask?.cancel()
        let window = self.window
        Task { @MainActor in
            window?.close()
        }
    }
}
