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
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

struct MicrophoneHUDView: View {
    let isMuted: Bool

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
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .shadow(color: .black.opacity(0.3), radius: 10)
        )
    }
}

class MicrophoneHUDController: ObservableObject {
    static let shared = MicrophoneHUDController()

    private var window: MicrophoneHUDWindow?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(isMuted: Bool) {
        // Cancel any existing hide task
        hideTask?.cancel()

        // Create or update window
        if window == nil {
            window = MicrophoneHUDWindow()
        }

        let contentView = MicrophoneHUDView(isMuted: isMuted)
        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView

        // Auto-size window to fit content
        hostingView.invalidateIntrinsicContentSize()
        let fittingSize = hostingView.fittingSize
        window?.setContentSize(fittingSize)

        // Re-center window after sizing
        if let screen = NSScreen.main, let window = window {
            let screenFrame = screen.frame
            let x = (screenFrame.width - fittingSize.width) / 2
            let y = (screenFrame.height - fittingSize.height) / 2 + 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show window with fade in
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1.0
        }

        // Auto-hide after 1.5 seconds
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            hide()
        }
    }

    func hide() {
        hideTask?.cancel()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }

    deinit {
        hideTask?.cancel()
        window?.close()
    }
}
