import SwiftUI
import AppKit

class VolumeHUDWindow: NSWindow {
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

struct VolumeHUDView: View {
    let volume: Float
    let isMuted: Bool
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)

            // Volume bar
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<16, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(volumeBarColor(for: index))
                            .frame(width: 8, height: 20)
                    }
                }

                // Percentage text
                if !isMuted {
                    Text("\(Int(volume * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .shadow(color: .black.opacity(0.3), radius: 10)
        )
    }

    private func volumeBarColor(for index: Int) -> Color {
        let filledBars = Int(volume * 16)
        if isMuted {
            return Color.gray.opacity(0.3)
        }
        return index < filledBars ? .white : Color.white.opacity(0.2)
    }
}

class VolumeHUDController: ObservableObject {
    static let shared = VolumeHUDController()

    private var window: VolumeHUDWindow?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(volume: Float, isMuted: Bool, icon: String = "speaker.wave.3.fill") {
        // Cancel any existing hide task
        hideTask?.cancel()

        // Create or update window
        if window == nil {
            window = VolumeHUDWindow()
        }

        let contentView = VolumeHUDView(
            volume: volume,
            isMuted: isMuted,
            icon: isMuted ? "speaker.slash.fill" : icon
        )
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

        // Show window with fade in - use orderFrontRegardless instead of makeKeyAndOrderFront
        window?.alphaValue = 0
        window?.orderFrontRegardless()  // Don't steal focus, just show above everything

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
