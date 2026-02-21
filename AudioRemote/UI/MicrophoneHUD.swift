import SwiftUI
import AppKit

class MicrophoneHUDWindow: NSWindow {
    init() {
        // Start with minimal size - will be auto-sized by content
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        // Use extremely high window level to ensure visibility above everything
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }
}

struct MicrophoneHUDView: View {
    let isMuted: Bool
    var warning: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)

            // Status text
            Text(isMuted ? "Mic Muted" : "Mic Active")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)

            // Optional warning
            if let warning = warning {
                Divider()
                    .background(Color.white.opacity(0.3))

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
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
class MicrophoneHUDController: ObservableObject {
    static let shared = MicrophoneHUDController()

    private var window: MicrophoneHUDWindow?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(isMuted: Bool, warning: String? = nil) {
        NSLog("🎤 MicrophoneHUD: Showing HUD - isMuted: \(isMuted), warning: \(warning ?? "none")")

        // Cancel any existing hide task
        hideTask?.cancel()

        // Create or update window
        if window == nil {
            window = MicrophoneHUDWindow()
            NSLog("🎤 MicrophoneHUD: Created new window")
        }

        let contentView = MicrophoneHUDView(isMuted: isMuted, warning: warning)
        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView

        // Force proper sizing - same as VolumeHUD
        hostingView.invalidateIntrinsicContentSize()
        let fittingSize = hostingView.fittingSize
        window?.setContentSize(fittingSize)

        NSLog("🎤 MicrophoneHUD: Window size: \(fittingSize)")

        // Re-center window after sizing
        if let screen = NSScreen.main, let window = window {
            let screenFrame = screen.frame
            let x = (screenFrame.width - fittingSize.width) / 2
            let y = (screenFrame.height - fittingSize.height) / 2 + 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
            NSLog("🎤 MicrophoneHUD: Window position: (\(x), \(y)), screen: \(screenFrame)")
        }

        // Show window with fade in - use orderFrontRegardless instead of makeKeyAndOrderFront
        window?.alphaValue = 0
        window?.orderFrontRegardless()  // Don't steal focus, just show above everything

        NSLog("🎤 MicrophoneHUD: Window ordered front, isVisible: \(window?.isVisible ?? false), level: \(window?.level.rawValue ?? 0)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1.0
        }

        // Auto-hide after 2.5 seconds (increased from 1.5s for better visibility)
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
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
