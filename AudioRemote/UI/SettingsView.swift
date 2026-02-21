import SwiftUI

// MARK: - Theme Colors
private enum ThemeColors {
    static let background = Color(red: 0.10, green: 0.10, blue: 0.18)     // #1a1a2e
    static let cardBg = Color(red: 0.12, green: 0.16, blue: 0.22)
    static let border = Color(red: 0.22, green: 0.25, blue: 0.32)
    static let textMuted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let textSecondary = Color(red: 0.61, green: 0.64, blue: 0.69)
    static let accent = Color(red: 0.06, green: 0.73, blue: 0.51)         // Green
    static let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let accentPurple = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let accentOrange = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let error = Color(red: 0.94, green: 0.27, blue: 0.27)
}

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var bridgeManager: BridgeManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var logManager: LogManager = .shared
    var restartServer: (() -> Void)? = nil
    @State private var localIP = NetworkService.getLocalIP()
    @State private var startTime = Date()
    @State private var currentTime = Date()

    // Timer for uptime
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HeaderView()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Feature Card - iOS Shortcut
                FeatureCard()
                    .padding(.horizontal, 24)

                // Stats Grid
                StatsGrid(
                    bridgeManager: bridgeManager,
                    settingsManager: settingsManager,
                    requestCount: settingsManager.settings.requestCount,
                    port: settingsManager.settings.httpPort,
                    uptime: uptimeString
                )
                .padding(.horizontal, 24)

                // Webhook URLs Section
                WebhookSection(
                    localIP: localIP,
                    port: settingsManager.settings.httpPort
                )
                .padding(.horizontal, 24)

                // Settings Section
                SettingsSection(settingsManager: settingsManager, bridgeManager: bridgeManager, restartServer: restartServer)
                    .padding(.horizontal, 24)

                // Update Section (Free Version - Opens GitHub)
                UpdateSection(updateManager: updateManager)
                    .padding(.horizontal, 24)

                // Connection Log Section
                ConnectionLogSection(logManager: logManager)
                    .padding(.horizontal, 24)

                // Network Info Section
                NetworkSection(
                    localIP: localIP,
                    port: settingsManager.settings.httpPort,
                    serverRunning: settingsManager.settings.httpServerEnabled
                )
                    .padding(.horizontal, 24)

                // Footer
                FooterView()
                    .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
        }
        .frame(width: 700, height: 800)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18), // #1a1a2e
                    Color(red: 0.09, green: 0.13, blue: 0.24)  // #16213e
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    var uptimeString: String {
        let elapsed = Int(currentTime.timeIntervalSince(startTime))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        HStack {
            HStack(spacing: 16) {
                // App Icon - Load from bundle
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(12)
                } else {
                    // Fallback if icon not found
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [ThemeColors.accent, ThemeColors.accentBlue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 48, height: 48)
                        .cornerRadius(12)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MicDrop Server")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Remote Audio Control")
                        .font(.system(size: 13))
                        .foregroundColor(ThemeColors.textSecondary)
                }
            }

            Spacer()

            // Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(ThemeColors.accent)
                    .frame(width: 8, height: 8)
                Text("Running")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ThemeColors.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ThemeColors.accent.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ThemeColors.accent, lineWidth: 1)
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    var body: some View {
        HStack {
            HStack(spacing: 16) {
                // Feature Icon
                ZStack {
                    Color.white.opacity(0.2)
                        .frame(width: 56, height: 56)
                        .cornerRadius(12)

                    Image(systemName: "iphone")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("iOS Shortcut")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text("READY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ThemeColors.accentOrange)
                            .cornerRadius(4)
                    }

                    Text("Control your Mac's mic from iPhone via Shortcuts app")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            Spacer()

            Button(action: {
                if let url = URL(string: "https://github.com/leolionart/Mac-Audio-Remote/blob/main/docs/iOS-SHORTCUTS-GUIDE.md") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Setup Guide")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeColors.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.37, blue: 0.27),
                    Color(red: 0.02, green: 0.47, blue: 0.34)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Stats Grid
struct StatsGrid: View {
    @ObservedObject var bridgeManager: BridgeManager
    @ObservedObject var settingsManager: SettingsManager
    let requestCount: Int
    let port: Int
    let uptime: String

    var body: some View {
        HStack(spacing: 16) {
            // Interactive Mic Toggle Card
            MicToggleCard(bridgeManager: bridgeManager, settingsManager: settingsManager)

            StatCard(
                icon: "⚡",
                label: "REQUESTS",
                value: "\(requestCount)",
                valueColor: ThemeColors.accentBlue,
                subtitle: "total"
            )

            StatCard(
                icon: "🌐",
                label: "PORT",
                value: "\(port)",
                valueColor: ThemeColors.accentPurple,
                subtitle: "HTTP"
            )

            StatCard(
                icon: "✅",
                label: "UPTIME",
                value: uptime,
                valueColor: ThemeColors.accentOrange,
                subtitle: "since start"
            )
        }
    }
}

// MARK: - Interactive Mic Toggle Card
struct MicToggleCard: View {
    @ObservedObject var bridgeManager: BridgeManager
    @ObservedObject var settingsManager: SettingsManager
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            _ = bridgeManager.toggle()
            settingsManager.incrementRequestCount()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("🎙️")
                        .font(.system(size: 12))
                    Text("MIC")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(bridgeManager.isMuted ? "OFF" : "ON")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(bridgeManager.isMuted ? ThemeColors.error : ThemeColors.accent)

                Text(isHovering ? "click to toggle" : (bridgeManager.isMuted ? "muted" : "active"))
                    .font(.system(size: 12))
                    .foregroundColor(isHovering ? ThemeColors.accent : ThemeColors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(isHovering ? ThemeColors.cardBg.opacity(0.8) : ThemeColors.cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? ThemeColors.accent : ThemeColors.border, lineWidth: isHovering ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bridgeManager.isMuted)
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeColors.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(valueColor)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(ThemeColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Webhook Section
struct WebhookSection: View {
    let localIP: String
    let port: Int

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Webhook URLs")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("HTTP API")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                // Microphone Control
                SectionDivider(title: "Microphone")
                URLDisplayRow(label: "Toggle Mic", url: "http://\(localIP):\(port)/toggle-mic")
                URLDisplayRow(label: "Mic Status", url: "http://\(localIP):\(port)/status")

                // Volume Control
                SectionDivider(title: "Volume")
                URLDisplayRow(label: "Vol Up", url: "http://\(localIP):\(port)/volume/increase")
                URLDisplayRow(label: "Vol Down", url: "http://\(localIP):\(port)/volume/decrease")
                URLDisplayRow(label: "Set Vol", url: "http://\(localIP):\(port)/volume/percent/{0-1}")
                URLDisplayRow(label: "Toggle Mute", url: "http://\(localIP):\(port)/volume/toggle-mute")
                URLDisplayRow(label: "Vol Status", url: "http://\(localIP):\(port)/volume/status")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Section Divider
struct SectionDivider: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ThemeColors.textMuted)
                .textCase(.uppercase)
                .tracking(1)
            Rectangle()
                .fill(ThemeColors.border)
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct URLDisplayRow: View {
    let label: String
    let url: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ThemeColors.textMuted)
                .textCase(.uppercase)
                .frame(width: 50, alignment: .leading)

            Text(url)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(ThemeColors.accent)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            }) {
                Text(copied ? "Copied!" : "Copy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(copied ? ThemeColors.accentBlue : ThemeColors.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ThemeColors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var bridgeManager: BridgeManager
    var restartServer: (() -> Void)? = nil
    @State private var isRestarting = false

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                SettingRow(
                    icon: "power.circle.fill",
                    title: "Start at Login",
                    description: "Launch server when macOS starts",
                    isOn: Binding(
                        get: { settingsManager.settings.autoStart },
                        set: { newValue in
                            settingsManager.settings.autoStart = newValue
                            settingsManager.save()
                            AutoStartService.shared.setEnabled(newValue)
                        }
                    )
                )

                Divider()
                    .background(ThemeColors.border)
                    .padding(.horizontal, 20)

                SettingRow(
                    icon: "globe",
                    title: "HTTP Server",
                    description: "Enable webhook server for remote control",
                    isOn: Binding(
                        get: { settingsManager.settings.httpServerEnabled },
                        set: { newValue in
                            settingsManager.settings.httpServerEnabled = newValue
                            settingsManager.save()
                        }
                    )
                )

                Divider()
                    .background(ThemeColors.border)
                    .padding(.horizontal, 20)

                // Extension Status
                ExtensionStatusRow(bridgeManager: bridgeManager)

                // Restart HTTP Server Button
                if settingsManager.settings.httpServerEnabled {
                    Divider()
                        .background(ThemeColors.border)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        ZStack {
                            ThemeColors.background
                                .frame(width: 36, height: 36)
                                .cornerRadius(8)
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isRestarting ? ThemeColors.textMuted : ThemeColors.accentOrange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("HTTP Server")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Text(isRestarting ? "Restarting..." : "Stop and restart the HTTP server")
                                .font(.system(size: 12))
                                .foregroundColor(ThemeColors.textMuted)
                        }

                        Spacer()

                        Button(action: {
                            guard !isRestarting else { return }
                            isRestarting = true
                            restartServer?()
                            // Reset state after 3s to allow button to be pressed again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                isRestarting = false
                            }
                        }) {
                            Text(isRestarting ? "..." : "Restart")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isRestarting ? ThemeColors.textMuted : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isRestarting ? ThemeColors.border : ThemeColors.accentOrange)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestarting || restartServer == nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .padding(.bottom, 20)
        }
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Extension Status Row
struct ExtensionStatusRow: View {
    @ObservedObject var bridgeManager: BridgeManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    ThemeColors.background
                        .frame(width: 36, height: 36)
                        .cornerRadius(8)

                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ThemeColors.accentBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chrome Extension Bridge")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("Control Google Meet when Chrome is not focused")
                        .font(.system(size: 12))
                        .foregroundColor(ThemeColors.textMuted)
                }

                Spacer()

                Text("ACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(ThemeColors.accent)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Installation link
            HStack {
                Text("Extension not working?")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)

                Button(action: {
                    if let url = URL(string: "https://github.com/leolionart/Mac-Audio-Remote/tree/main/chrome-extension") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Installation Guide")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.accentBlue)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon (using SF Symbols)
            ZStack {
                ThemeColors.background
                    .frame(width: 36, height: 36)
                    .cornerRadius(8)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(ThemeColors.accent)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CustomToggleStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Custom Toggle Style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 28)
                .fill(configuration.isOn ? ThemeColors.accent : ThemeColors.background)
                .frame(width: 50, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(configuration.isOn ? ThemeColors.accent : ThemeColors.border, lineWidth: 2)
                )

            // Knob
            Circle()
                .fill(configuration.isOn ? Color.white : ThemeColors.textSecondary)
                .frame(width: 20, height: 20)
                .offset(x: configuration.isOn ? 11 : -11)
                .animation(.spring(response: 0.3), value: configuration.isOn)
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

// MARK: - Update Section
struct UpdateSection: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Software Update")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                // Update Status
                HStack(spacing: 12) {
                    ZStack {
                        ThemeColors.background
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)

                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ThemeColors.accentOrange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Version")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                            .font(.system(size: 12))
                            .foregroundColor(ThemeColors.textMuted)
                    }

                    Spacer()

                    if let lastCheck = updateManager.lastCheckDate {
                        Text("Checked: \(formatDate(lastCheck))")
                            .font(.system(size: 11))
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
                .padding(.horizontal, 20)

                // Dynamic Action Area
                Group {
                    switch updateManager.state {
                    case .idle, .upToDate, .error:
                        VStack(spacing: 8) {
                            Button(action: {
                                updateManager.checkForUpdates()
                            }) {
                                HStack {
                                    Text("Check for Updates")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ThemeColors.accentBlue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            if case .error(let msg) = updateManager.state {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(ThemeColors.error)
                            }
                        }

                    case .checking:
                        HStack {
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Checking for updates...")
                                .font(.system(size: 13))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ThemeColors.background)
                        .cornerRadius(8)

                    case .available(let info):
                        VStack(spacing: 8) {
                            Text("New version available: \(info.version)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ThemeColors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: {
                                updateManager.downloadUpdate(info)
                            }) {
                                Text("Download & Install")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(ThemeColors.accent)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                    case .downloading(let progress):
                        VStack(spacing: 8) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: ThemeColors.accent))
                            Text("Downloading... \(Int(progress * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(ThemeColors.textSecondary)
                        }

                    case .installing:
                        HStack {
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Installing update...")
                                .font(.system(size: 13))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Info message
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(ThemeColors.textMuted)
                    Text("Updates are fetched directly from GitHub Releases")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(ThemeColors.background)
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Network Section
struct NetworkSection: View {
    let localIP: String
    let port: Int
    let serverRunning: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Network Info")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Local Network")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                ConnectionItem(icon: "desktopcomputer", label: localIP, isActive: serverRunning)
                ConnectionItem(icon: "globe", label: "localhost:\(port)", isActive: serverRunning)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

struct ConnectionItem: View {
    let icon: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isActive ? ThemeColors.accent : ThemeColors.textMuted)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white)
            Circle()
                .fill(isActive ? ThemeColors.accent : ThemeColors.textMuted)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ThemeColors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? ThemeColors.accent : ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(20)
    }
}

// MARK: - Connection Log Section

struct ConnectionLogSection: View {
    @ObservedObject var logManager: LogManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ThemeColors.accent)
                        .frame(width: 8, height: 8)
                    Text("Connection Log")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: { logManager.clear() }) {
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeColors.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ThemeColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ThemeColors.border, lineWidth: 1)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if logManager.entries.isEmpty {
                            Text("No activity yet. Make a request to see logs.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(ThemeColors.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(logManager.entries) { entry in
                                LogEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 200)
                .background(ThemeColors.background)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .onChange(of: logManager.entries.count) { _ in
                    if let last = logManager.entries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Tip
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(ThemeColors.textMuted)
                Text("/bridge/poll (long-poll) is hidden from log to reduce noise")
                    .font(.system(size: 11))
                    .foregroundColor(ThemeColors.textMuted)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(ThemeColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.border, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: entry.timestamp)
    }

    private var color: Color {
        switch entry.type {
        case .success:  return ThemeColors.accent
        case .error:    return ThemeColors.error
        case .request:  return ThemeColors.accentBlue
        case .warning:  return ThemeColors.accentOrange
        case .info:     return ThemeColors.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ThemeColors.textMuted)
                .frame(width: 60, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
}

// MARK: - Footer View
struct FooterView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("MicDrop v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                .font(.system(size: 12))
                .foregroundColor(ThemeColors.textMuted)

            HStack(spacing: 4) {
                Text("Made with")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(ThemeColors.error)
                Text("using Swift")
                    .font(.system(size: 12))
                    .foregroundColor(ThemeColors.textMuted)
            }
        }
    }
}
