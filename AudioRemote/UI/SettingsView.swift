import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var updateManager: UpdateManager
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
                    audioManager: audioManager,
                    requestCount: settingsManager.settings.requestCount,
                    port: settingsManager.settings.httpPort,
                    uptime: uptimeString
                )
                .padding(.horizontal, 24)

                // Webhook URLs Section
                WebhookSection(
                    localIP: localIP,
                    port: settingsManager.settings.httpPort,
                    audioManager: audioManager,
                    settingsManager: settingsManager
                )
                .padding(.horizontal, 24)

                // Settings Section
                SettingsSection(settingsManager: settingsManager)
                    .padding(.horizontal, 24)

                // Update Section
                UpdateSection(updateManager: updateManager)
                    .padding(.horizontal, 24)

                // Network Info Section
                NetworkSection(localIP: localIP, port: settingsManager.settings.httpPort)
                    .padding(.horizontal, 24)

                // Footer
                FooterView()
                    .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
        }
        .frame(width: 700, height: 600)
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
                // App Icon
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.06, green: 0.73, blue: 0.51), // #10b981
                            Color(red: 0.23, green: 0.51, blue: 0.96)  // #3b82f6
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 48, height: 48)
                    .cornerRadius(12)

                    Text("🎤")
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Audio Remote Server")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Remote Audio Control")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.61, green: 0.64, blue: 0.69))
                }
            }

            Spacer()

            // Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.06, green: 0.73, blue: 0.51))
                    .frame(width: 8, height: 8)
                Text("Running")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 0.06, green: 0.73, blue: 0.51), lineWidth: 1)
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

                    Text("📱")
                        .font(.system(size: 28))
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
                            .background(Color(red: 0.96, green: 0.62, blue: 0.04))
                            .cornerRadius(4)
                    }

                    Text("Control your Mac's mic from iPhone via Shortcuts app")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            Spacer()

            Button(action: {
                if let url = URL(string: "https://support.apple.com/guide/shortcuts/welcome/ios") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Setup Guide")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
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
    @ObservedObject var audioManager: AudioManager
    let requestCount: Int
    let port: Int
    let uptime: String

    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "🎙️",
                label: "MIC STATUS",
                value: audioManager.isMuted ? "OFF" : "ON",
                valueColor: audioManager.isMuted ? Color(red: 0.94, green: 0.27, blue: 0.27) : Color(red: 0.06, green: 0.73, blue: 0.51),
                subtitle: audioManager.isMuted ? "muted" : "active"
            )

            StatCard(
                icon: "⚡",
                label: "REQUESTS",
                value: "\(requestCount)",
                valueColor: Color(red: 0.23, green: 0.51, blue: 0.96),
                subtitle: "total"
            )

            StatCard(
                icon: "🌐",
                label: "PORT",
                value: "\(port)",
                valueColor: Color(red: 0.55, green: 0.36, blue: 0.96),
                subtitle: "HTTP"
            )

            StatCard(
                icon: "✅",
                label: "UPTIME",
                value: uptime,
                valueColor: Color(red: 0.96, green: 0.62, blue: 0.04),
                subtitle: "since start"
            )
        }
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
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(valueColor)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.12, green: 0.16, blue: 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Webhook Section
struct WebhookSection: View {
    let localIP: String
    let port: Int
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var settingsManager: SettingsManager

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
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
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
                URLDisplayRow(label: "Toggle Mute", url: "http://\(localIP):\(port)/volume/toggle-mute")
                URLDisplayRow(label: "Vol Status", url: "http://\(localIP):\(port)/volume/status")
            }
            .padding(.horizontal, 20)

            Button(action: {
                let muted = audioManager.toggle()
                settingsManager.incrementRequestCount()
                if settingsManager.settings.notificationsEnabled {
                    NotificationService.shared.showMicToggle(isMuted: muted, source: "Settings")
                }
            }) {
                HStack {
                    Text("🎤")
                    Text("Test Toggle Mic")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.23, green: 0.51, blue: 0.96))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.12, green: 0.16, blue: 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
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
                .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                .textCase(.uppercase)
                .tracking(1)
            Rectangle()
                .fill(Color(red: 0.22, green: 0.25, blue: 0.32))
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
                .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                .textCase(.uppercase)
                .frame(width: 50, alignment: .leading)

            Text(url)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
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
                    .background(copied ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.06, green: 0.73, blue: 0.51))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.10, green: 0.10, blue: 0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    @ObservedObject var settingsManager: SettingsManager

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
                    icon: "🚀",
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
                    .background(Color(red: 0.22, green: 0.25, blue: 0.32))
                    .padding(.horizontal, 20)

                SettingRow(
                    icon: "🔔",
                    title: "Notifications",
                    description: "Show alerts when mic state changes",
                    isOn: Binding(
                        get: { settingsManager.settings.notificationsEnabled },
                        set: { newValue in
                            settingsManager.settings.notificationsEnabled = newValue
                            settingsManager.save()
                        }
                    )
                )

                Divider()
                    .background(Color(red: 0.22, green: 0.25, blue: 0.32))
                    .padding(.horizontal, 20)

                SettingRow(
                    icon: "🌐",
                    title: "HTTP Server",
                    description: "Enable webhook server for remote control",
                    isOn: Binding(
                        get: { settingsManager.settings.httpServerEnabled },
                        set: { newValue in
                            settingsManager.settings.httpServerEnabled = newValue
                            settingsManager.save()
                        }
                    ),
                    isLast: true
                )
            }
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.12, green: 0.16, blue: 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
        )
        .cornerRadius(16)
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
            // Icon
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.18)
                    .frame(width: 36, height: 36)
                    .cornerRadius(8)

                Text(icon)
                    .font(.system(size: 18))
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
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
                .fill(configuration.isOn ?
                      Color(red: 0.06, green: 0.73, blue: 0.51) :
                      Color(red: 0.10, green: 0.10, blue: 0.18))
                .frame(width: 50, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(configuration.isOn ?
                               Color(red: 0.06, green: 0.73, blue: 0.51) :
                               Color(red: 0.22, green: 0.25, blue: 0.32),
                               lineWidth: 2)
                )

            // Knob
            Circle()
                .fill(configuration.isOn ? Color.white : Color(red: 0.61, green: 0.64, blue: 0.69))
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
    @State private var isChecking = false

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
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)

                        Text("🔄")
                            .font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Version")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Version 2.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                    }

                    Spacer()

                    if let lastCheck = updateManager.lastUpdateCheckDate {
                        Text("Last: \(formatDate(lastCheck))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                    }
                }
                .padding(.horizontal, 20)

                // Check for Updates Button
                Button(action: {
                    isChecking = true
                    updateManager.checkForUpdates()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isChecking = false
                    }
                }) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isChecking ? "Checking..." : "Check for Updates")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.23, green: 0.51, blue: 0.96))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isChecking)
                .padding(.horizontal, 20)

                Divider()
                    .background(Color(red: 0.22, green: 0.25, blue: 0.32))
                    .padding(.horizontal, 20)

                // Auto Update Settings
                HStack(spacing: 12) {
                    ZStack {
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)

                        Text("⚙️")
                            .font(.system(size: 18))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Update")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Automatically check for updates")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { updateManager.automaticallyChecksForUpdates },
                        set: { updateManager.automaticallyChecksForUpdates = $0 }
                    ))
                    .toggleStyle(CustomToggleStyle())
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.12, green: 0.16, blue: 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
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
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                ConnectionItem(icon: "💻", label: localIP, isActive: true)
                ConnectionItem(icon: "🌐", label: "localhost:\(port)", isActive: false)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.12, green: 0.16, blue: 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 1)
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
            Text(icon)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white)
            Circle()
                .fill(isActive ?
                     Color(red: 0.06, green: 0.73, blue: 0.51) :
                     Color(red: 0.42, green: 0.45, blue: 0.50))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 0.10, green: 0.10, blue: 0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ?
                       Color(red: 0.06, green: 0.73, blue: 0.51) :
                       Color(red: 0.22, green: 0.25, blue: 0.32),
                       lineWidth: 1)
        )
        .cornerRadius(20)
    }
}

// MARK: - Footer View
struct FooterView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Audio Remote Server v2.0")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))

            HStack(spacing: 4) {
                Text("Made with")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
                Text("❤️")
                    .font(.system(size: 10))
                Text("using Swift")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50))
            }
        }
    }
}
