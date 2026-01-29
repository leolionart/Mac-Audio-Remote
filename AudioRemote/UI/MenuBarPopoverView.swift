import SwiftUI
import Cocoa

// MARK: - Menu Bar Popover View
struct MenuBarPopoverView: View {
    @ObservedObject var bridgeManager: BridgeManager
    @ObservedObject var settingsManager: SettingsManager
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with status and controls
            HeaderSection(
                isMuted: bridgeManager.isMuted,
                serverRunning: settingsManager.settings.httpServerEnabled,
                openSettings: openSettings
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Mic Control Section
            MicControlSection(
                isMuted: bridgeManager.isMuted,
                toggleMic: {
                    let muted = bridgeManager.toggle()
                    settingsManager.incrementRequestCount()

                    // Show HUD overlay
                    MicrophoneHUDController.shared.show(isMuted: muted)
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Volume Control Section
            VolumeControlSection(
                volume: bridgeManager.outputVolume,
                isMuted: bridgeManager.isOutputMuted,
                increaseVolume: {
                    bridgeManager.increaseOutputVolume()
                },
                decreaseVolume: {
                    bridgeManager.decreaseOutputVolume()
                },
                toggleMute: {
                    bridgeManager.toggleOutputMute()
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer Actions
            FooterSection(
                openSettings: openSettings,
                quit: quit
            )
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    let isMuted: Bool
    let serverRunning: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 6) {
                Text(isMuted ? "🔇" : "🎤")
                    .font(.system(size: 16))
                Text(isMuted ? "Muted" : "Active")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
            )

            Spacer()

            // Server status
            HStack(spacing: 4) {
                Circle()
                    .fill(serverRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text("Server")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
            )

            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Mic Control Section
// MARK: - Volume Control Section
struct VolumeControlSection: View {
    let volume: Float
    let isMuted: Bool
    let increaseVolume: () -> Void
    let decreaseVolume: () -> Void
    let toggleMute: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Speaker Volume")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Control buttons
            HStack(spacing: 8) {
                // Decrease
                ControlButton(
                    icon: "speaker.wave.1.fill",
                    label: "Decrease",
                    action: decreaseVolume
                )

                // Mute toggle
                ControlButton(
                    icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: isMuted ? "Unmute" : "Mute",
                    isDestructive: isMuted,
                    action: toggleMute
                )

                // Increase
                ControlButton(
                    icon: "speaker.wave.3.fill",
                    label: "Increase",
                    action: increaseVolume
                )
            }

            // Volume slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isMuted ?
                                    [Color.gray, Color.gray] :
                                    [Color.blue.opacity(0.8), Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(volume), height: 12)

                    // Speaker icons
                    HStack {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.leading, 6)

                        Spacer()

                        if volume > 0.9 {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.trailing, 6)
                        }
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? .red : .blue)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDestructive ? Color.red.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer Section
struct FooterSection: View {
    let openSettings: () -> Void
    let quit: () -> Void

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Action buttons
            HStack(spacing: 8) {
                Button(action: openSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                Button(action: quit) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                        Text("Quit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            // Version info
            Text("MicDrop v\(version)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Mic Control Section
struct MicControlSection: View {
    let isMuted: Bool
    let toggleMic: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Microphone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            // Toggle button
            Button(action: toggleMic) {
                HStack(spacing: 12) {
                    Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Text(isMuted ? "Unmute Microphone" : "Mute Microphone")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text("⌥M")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isMuted ?
                              Color.red.opacity(0.8) :
                              Color.green.opacity(0.7))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
