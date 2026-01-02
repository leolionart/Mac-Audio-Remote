import Foundation
import Vapor

class HTTPServer {
    private var app: Application?
    private let audioManager: AudioManager
    private let settingsManager: SettingsManager
    private var isRunning = false
    private var restartTask: Task<Void, Never>?
    private var errorCount = 0
    private let maxErrors = 3
    private let restartDelay: UInt64 = 5_000_000_000 // 5 seconds in nanoseconds

    init(audioManager: AudioManager, settingsManager: SettingsManager) {
        self.audioManager = audioManager
        self.settingsManager = settingsManager
    }

    deinit {
        restartTask?.cancel()
        stop()
    }

    // MARK: - Public Methods

    func start(port: Int = 8765) throws {
        guard !isRunning else {
            print("HTTP server already running")
            return
        }

        // Check if port is available
        guard NetworkService.isPortAvailable(port: port) else {
            throw HTTPServerError.portNotAvailable(port)
        }

        var env = Environment.production
        env.arguments = ["vapor"]

        app = Application(env)

        // Configure routes
        configureRoutes(app!)

        // Bind to port
        app?.http.server.configuration.hostname = "0.0.0.0"
        app?.http.server.configuration.port = port

        // Start server in background with error recovery
        Task {
            do {
                try await app?.execute()
            } catch {
                print("HTTP server error: \(error)")
                await handleServerError()
            }
        }

        isRunning = true
        let localIP = NetworkService.getLocalIP()
        print("HTTP server started on http://\(localIP):\(port)")
    }

    func stop() {
        guard isRunning else { return }

        restartTask?.cancel()
        app?.shutdown()
        app = nil
        isRunning = false
        errorCount = 0 // Reset error count on manual stop
        print("HTTP server stopped")
    }

    // MARK: - Private Methods

    private func configureRoutes(_ app: Application) {
        // CORS middleware
        app.middleware.use(CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin]
        )))

        // POST /toggle-mic
        app.post("toggle-mic") { [weak self] req async throws -> ToggleResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            let muted = self.audioManager.toggle()
            self.settingsManager.incrementRequestCount()

            // Show notification if enabled
            if self.settingsManager.settings.notificationsEnabled {
                NotificationService.shared.showMicToggle(isMuted: muted, source: "Remote")
            }

            return ToggleResponse(status: "ok", muted: muted)
        }

        // GET /status
        app.get("status") { [weak self] req throws -> StatusResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            return StatusResponse(
                muted: self.audioManager.isMuted,
                outputVolume: self.audioManager.outputVolume,
                outputMuted: self.audioManager.isOutputMuted
            )
        }

        // MARK: - Volume Control Endpoints

        // POST /volume/increase
        app.post("volume", "increase") { [weak self] req async throws -> VolumeResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            let step = self.settingsManager.settings.volumeStep
            self.audioManager.increaseOutputVolume(step)
            self.settingsManager.incrementRequestCount()

            return VolumeResponse(
                status: "ok",
                volume: self.audioManager.outputVolume,
                muted: self.audioManager.isOutputMuted
            )
        }

        // POST /volume/decrease
        app.post("volume", "decrease") { [weak self] req async throws -> VolumeResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            let step = self.settingsManager.settings.volumeStep
            self.audioManager.decreaseOutputVolume(step)
            self.settingsManager.incrementRequestCount()

            return VolumeResponse(
                status: "ok",
                volume: self.audioManager.outputVolume,
                muted: self.audioManager.isOutputMuted
            )
        }

        // POST /volume/set
        app.post("volume", "set") { [weak self] req async throws -> VolumeResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            struct SetVolumeRequest: Content {
                let volume: Float
            }

            let request = try req.content.decode(SetVolumeRequest.self)
            self.audioManager.setOutputVolume(request.volume)
            self.settingsManager.incrementRequestCount()

            return VolumeResponse(
                status: "ok",
                volume: self.audioManager.outputVolume,
                muted: self.audioManager.isOutputMuted
            )
        }

        // POST /volume/toggle-mute
        app.post("volume", "toggle-mute") { [weak self] req async throws -> VolumeResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            let muted = self.audioManager.toggleOutputMute()
            self.settingsManager.incrementRequestCount()

            // Show notification if enabled
            if self.settingsManager.settings.notificationsEnabled {
                NotificationService.shared.show(
                    title: muted ? "🔇 Volume Muted" : "🔊 Volume Unmuted",
                    body: "Toggled from Remote"
                )
            }

            return VolumeResponse(
                status: "ok",
                volume: self.audioManager.outputVolume,
                muted: self.audioManager.isOutputMuted
            )
        }

        // GET /volume/status
        app.get("volume", "status") { [weak self] req throws -> VolumeResponse in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            return VolumeResponse(
                status: "ok",
                volume: self.audioManager.outputVolume,
                muted: self.audioManager.isOutputMuted
            )
        }

        // GET / - Web UI
        app.get { [weak self] req throws -> Response in
            guard let self = self else {
                throw Abort(.internalServerError, reason: "Server not initialized")
            }

            let localIP = NetworkService.getLocalIP()
            let port = self.settingsManager.settings.httpPort
            let micStatus = self.audioManager.isMuted ? "Muted 🔇" : "Active 🎤"
            let volumePercent = Int(self.audioManager.outputVolume * 100)
            let volumeStatus = self.audioManager.isOutputMuted ? "Muted 🔇" : "\(volumePercent)% 🔊"

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Audio Remote Server</title>
                <style>
                    * {
                        margin: 0;
                        padding: 0;
                        box-sizing: border-box;
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        padding: 40px;
                        text-align: center;
                        background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                        color: white;
                        min-height: 100vh;
                        display: flex;
                        flex-direction: column;
                        align-items: center;
                        justify-content: center;
                    }
                    h1 {
                        color: #10b981;
                        font-size: 3rem;
                        margin-bottom: 1rem;
                    }
                    .status {
                        color: #10b981;
                        font-size: 1.5rem;
                        margin-bottom: 2rem;
                    }
                    .info {
                        background: rgba(255, 255, 255, 0.1);
                        padding: 2rem;
                        border-radius: 12px;
                        margin: 1rem 0;
                        max-width: 600px;
                    }
                    code {
                        background: rgba(0, 0, 0, 0.3);
                        padding: 12px 20px;
                        border-radius: 8px;
                        font-size: 14px;
                        display: inline-block;
                        margin: 0.5rem 0;
                        word-break: break-all;
                    }
                    .mic-status {
                        font-size: 1.2rem;
                        margin: 1rem 0;
                        padding: 1rem;
                        background: rgba(16, 185, 129, 0.2);
                        border-radius: 8px;
                    }
                    .footer {
                        margin-top: 2rem;
                        color: rgba(255, 255, 255, 0.5);
                        font-size: 0.9rem;
                    }
                    h2 {
                        color: #10b981;
                        margin: 1.5rem 0 0.5rem 0;
                    }
                    p {
                        margin: 0.5rem 0;
                        line-height: 1.6;
                    }
                </style>
            </head>
            <body>
                <h1>🎵 Audio Remote Server</h1>
                <div class="status">✅ Running</div>

                <div class="mic-status">
                    Microphone: <strong>\(micStatus)</strong><br>
                    Volume: <strong>\(volumeStatus)</strong>
                </div>

                <div class="info">
                    <h2>Microphone Control</h2>
                    <p><strong>Toggle Microphone:</strong></p>
                    <code>POST http://\(localIP):\(port)/toggle-mic</code>

                    <p style="margin-top: 1.5rem;"><strong>Get Status:</strong></p>
                    <code>GET http://\(localIP):\(port)/status</code>
                </div>

                <div class="info">
                    <h2>Volume Control</h2>
                    <p><strong>Increase Volume (+\(Int(self.settingsManager.settings.volumeStep * 100))%):</strong></p>
                    <code>POST http://\(localIP):\(port)/volume/increase</code>

                    <p style="margin-top: 1.5rem;"><strong>Decrease Volume (-\(Int(self.settingsManager.settings.volumeStep * 100))%):</strong></p>
                    <code>POST http://\(localIP):\(port)/volume/decrease</code>

                    <p style="margin-top: 1.5rem;"><strong>Set Volume (0.0-1.0):</strong></p>
                    <code>POST http://\(localIP):\(port)/volume/set</code>
                    <p style="font-size: 0.85rem; margin-top: 0.5rem;">Body: {"volume": 0.5}</p>

                    <p style="margin-top: 1.5rem;"><strong>Toggle Mute:</strong></p>
                    <code>POST http://\(localIP):\(port)/volume/toggle-mute</code>

                    <p style="margin-top: 1.5rem;"><strong>Get Volume Status:</strong></p>
                    <code>GET http://\(localIP):\(port)/volume/status</code>
                </div>

                <div class="info">
                    <h2>iOS Shortcuts Setup</h2>
                    <p>1. Open Shortcuts app on iPhone</p>
                    <p>2. Create new shortcut</p>
                    <p>3. Add "Get Contents of URL" action</p>
                    <p>4. Set URL to toggle endpoint</p>
                    <p>5. Set method to POST</p>
                    <p>6. Add to Home Screen for quick access</p>
                </div>

                <div class="footer">
                    Audio Remote v2.0 - Swift Edition<br>
                    Total Requests: \(self.settingsManager.settings.requestCount)
                </div>
            </body>
            </html>
            """

            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/html; charset=utf-8")]),
                body: .init(string: html)
            )
        }
    }

    // MARK: - Error Recovery

    private func handleServerError() async {
        errorCount += 1

        guard errorCount <= maxErrors else {
            print("HTTP server exceeded max error count (\(maxErrors)). Auto-restart disabled.")
            isRunning = false
            return
        }

        print("HTTP server error occurred (\(errorCount)/\(maxErrors)). Attempting restart in 5 seconds...")

        // Cancel any existing restart task
        restartTask?.cancel()

        // Schedule restart
        restartTask = Task {
            try? await Task.sleep(nanoseconds: restartDelay)

            guard !Task.isCancelled else {
                print("Restart task cancelled")
                return
            }

            print("Restarting HTTP server...")

            // Stop current server
            await MainActor.run {
                self.app?.shutdown()
                self.app = nil
                self.isRunning = false
            }

            // Attempt restart
            await MainActor.run {
                do {
                    try self.start(port: self.settingsManager.settings.httpPort)
                    self.errorCount = 0 // Reset error count on successful restart
                    print("HTTP server restarted successfully")
                } catch {
                    print("Failed to restart HTTP server: \(error)")
                }
            }
        }
    }
}

// MARK: - Response Models

struct ToggleResponse: Content {
    let status: String
    let muted: Bool
}

struct StatusResponse: Content {
    let muted: Bool
    let outputVolume: Float
    let outputMuted: Bool
}

struct VolumeResponse: Content {
    let status: String
    let volume: Float
    let muted: Bool
}

// MARK: - Errors

enum HTTPServerError: Error, CustomStringConvertible {
    case portNotAvailable(Int)

    var description: String {
        switch self {
        case .portNotAvailable(let port):
            return "Port \(port) is not available. Another application may be using it."
        }
    }
}
