import Foundation
import Vapor

class HTTPServer {
    private var app: Application?
    private let bridgeManager: BridgeManager
    private let settingsManager: SettingsManager
    private var isRunning = false
    private var restartTask: Task<Void, Never>?
    private var errorCount = 0
    private let maxErrors = 3
    private let restartDelay: UInt64 = 5_000_000_000 // 5 seconds

    init(bridgeManager: BridgeManager, settingsManager: SettingsManager) {
        self.bridgeManager = bridgeManager
        self.settingsManager = settingsManager
    }

    deinit {
        restartTask?.cancel()
        app?.shutdown()
        app = nil
    }

    @MainActor
    func start(port: Int = 8765) async throws {
        guard !isRunning else { return }
        LogManager.shared.log("Starting HTTP server on port \(port)…", type: .info)
        print("[HTTPServer] Starting on port \(port)")

        if !NetworkService.isPortAvailable(port: port) {
            LogManager.shared.log("⚠️ Port \(port) busy, attempting cleanup…", type: .warning)
            print("⚠️ Port \(port) not available, attempting auto-cleanup...")
            if NetworkService.killAudioRemoteOnPort(port: port) {
                LogManager.shared.log("✅ Port cleanup successful", type: .success)
                print("✅ Cleanup successful")
            } else {
                LogManager.shared.log("✗ Port \(port) still busy — cannot start server", type: .error)
                throw HTTPServerError.portNotAvailable(port)
            }
        }

        var env = Environment.production
        env.arguments = ["vapor"]
        app = try await Application.make(env)

        configureRoutes(app!)

        app?.http.server.configuration.hostname = "0.0.0.0"
        app?.http.server.configuration.port = port

        Task {
            do {
                try await app?.execute()
            } catch {
                print("HTTP server error: \(error)")
                await handleServerError()
            }
        }

        isRunning = true
        LogManager.shared.log("✅ Server started on port \(port) — ready", type: .success)
        print("HTTP server started on port \(port)")
    }

    func stop() async {
        guard isRunning else { return }
        restartTask?.cancel()
        // Cancel all pending long-poll and confirmation continuations first
        // so Vapor's asyncShutdown() doesn't hang waiting for in-flight requests
        bridgeManager.cancelAllPending()
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms grace period
        try? await app?.asyncShutdown()
        app = nil
        isRunning = false
        LogManager.shared.log("Server stopped", type: .info)
        print("HTTP server stopped")
    }

    @MainActor
    func restart() async {
        let port = settingsManager.settings.httpPort
        print("[HTTPServer] Restarting on port \(port)...")
        await stop()
        try? await start(port: port)
    }

    private func configureRoutes(_ app: Application) {
        // Request/response logging middleware (added first so it wraps everything)
        app.middleware.use(RequestLogMiddleware())

        app.middleware.use(CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin]
        )))

        // MARK: - Legacy iOS Endpoints

        // POST /toggle-mic - Toggle with confirmation (waits for extension if connected)
        app.post("toggle-mic") { [weak self] req async throws -> ToggleResponse in
            guard let self = self else { throw Abort(.internalServerError) }

            // Record whether extension was connected before toggling
            let extensionWasConnected = self.bridgeManager.isExtensionConnected

            // Wait for extension confirmation (3 second timeout)
            let toggleResult = await self.bridgeManager.toggleWithConfirmation(timeout: 3.0)
            let muted = self.bridgeManager.isMuted

            // confirmed = true only if extension was connected AND it responded
            let confirmed = extensionWasConnected && toggleResult
            let source = confirmed ? "extension" : "local"

            if !confirmed {
                print("⚠️ Toggle applied locally — extension \(extensionWasConnected ? "timeout" : "not connected")")
            }

            self.settingsManager.incrementRequestCount()

            // Show HUD on main thread
            DispatchQueue.main.async {
                let warning: String? = confirmed ? nil
                    : (extensionWasConnected ? "Extension didn't respond" : "No meeting app active")
                MicrophoneHUDController.shared.show(isMuted: muted, warning: warning)
            }

            // Always return "ok" — toggle was applied regardless of extension confirmation.
            return ToggleResponse(status: "ok", muted: muted, confirmed: confirmed, source: source)
        }

        // POST /toggle-mic/fast - Legacy optimistic toggle (no waiting)
        app.post("toggle-mic", "fast") { [weak self] req throws -> ToggleResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            let muted = self.bridgeManager.toggle()
            self.settingsManager.incrementRequestCount()

            // Show HUD overlay on main thread
            DispatchQueue.main.async {
                MicrophoneHUDController.shared.show(isMuted: muted)
            }

            return ToggleResponse(status: "ok", muted: muted, confirmed: false, source: "local")
        }

        app.get("status") { [weak self] req throws -> StatusResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            return StatusResponse(
                muted: self.bridgeManager.isMuted,
                outputVolume: self.bridgeManager.outputVolume,
                outputMuted: self.bridgeManager.isOutputMuted,
                muteMode: "bridge",
                currentInputDevice: self.bridgeManager.currentInputDeviceName,
                realMic: "Chrome Extension"
            )
        }

        // MARK: - Bridge Endpoints (New)

        // Extension reports state change (e.g. user clicked mute in Meet UI)
        app.post("bridge", "mic-state") { [weak self] req throws -> ToggleResponse in
            guard let self = self else { throw Abort(.internalServerError) }

            struct StateRequest: Content {
                let muted: Bool
            }
            let body = try req.content.decode(StateRequest.self)

            self.bridgeManager.updateMicState(muted: body.muted)
            return ToggleResponse(status: "updated", muted: body.muted, confirmed: true, source: "extension")
        }

        // Long-polling endpoint for extension
        app.get("bridge", "poll") { [weak self] req async throws -> BridgeEventResponse in
            guard let self = self else { throw Abort(.internalServerError) }

            // Wait for next event (suspends request until event occurs)
            let event = await self.bridgeManager.waitForNextEvent()
            return BridgeEventResponse(event: event.rawValue)
        }

        // MARK: - Server Control

        // POST /restart - Gracefully restart the HTTP server
        // Responds immediately then restarts after 500ms to ensure response is delivered
        app.post("restart") { [weak self] req async throws -> RestartResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            print("[HTTPServer] /restart endpoint called")

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms so response is sent first
                await self?.restart()
            }

            return RestartResponse(status: "restarting", message: "HTTP server will restart in 500ms")
        }

        // Volume endpoints (simplified)
        app.post("volume", "increase") { [weak self] req throws -> VolumeResponse in
            self?.bridgeManager.increaseOutputVolume()
            return VolumeResponse(status: "ok", volume: self?.bridgeManager.outputVolume ?? 0, muted: false)
        }

        app.post("volume", "decrease") { [weak self] req throws -> VolumeResponse in
            self?.bridgeManager.decreaseOutputVolume()
            return VolumeResponse(status: "ok", volume: self?.bridgeManager.outputVolume ?? 0, muted: false)
        }

        // Web UI
        app.get { [weak self] req in
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>MicDrop Bridge</title>
                <meta charset="utf-8">
            </head>
            <body style="font-family: system-ui; text-align: center; padding: 50px; background: #1a1a2e; color: #fff;">
                <h1 style="color: #10b981;">MicDrop Bridge Active</h1>
                <p>Use Chrome Extension to control Google Meet</p>
                <div style="margin: 20px; padding: 20px; background: rgba(255,255,255,0.1); border-radius: 12px; display: inline-block;">
                    <span style="font-size: 24px; font-weight: bold;">
                        \(self?.bridgeManager.isMuted == true ? "Muted 🔇" : "Active 🎤")
                    </span>
                </div>
                <p style="color: #aaa; font-size: 12px; margin-top: 40px;">MicDrop Server Running on Port \(self?.settingsManager.settings.httpPort ?? 8765)</p>
            </body>
            </html>
            """
        }
    }

    private func handleServerError() async {
        // Simplified error handling
        errorCount += 1
        guard errorCount <= maxErrors else { isRunning = false; return }
        try? await Task.sleep(nanoseconds: restartDelay)
        await stop()
        try? await start(port: settingsManager.settings.httpPort)
    }
}

// Response structs
struct ToggleResponse: Content {
    let status: String
    let muted: Bool
    let confirmed: Bool   // true = Chrome Extension confirmed the action in meeting app
    let source: String    // "extension" or "local"
}

struct StatusResponse: Content {
    let muted: Bool
    let outputVolume: Float
    let outputMuted: Bool
    let muteMode: String
    let currentInputDevice: String
    let realMic: String?
}

struct VolumeResponse: Content {
    let status: String
    let volume: Float
    let muted: Bool
}

struct BridgeEventResponse: Content {
    let event: String
}

struct RestartResponse: Content {
    let status: String
    let message: String
}

enum HTTPServerError: Error {
    case portNotAvailable(Int)
}

// MARK: - Request Logging Middleware

struct RequestLogMiddleware: AsyncMiddleware {
    // Skip logging for these noisy long-poll endpoints
    private let skipPaths: Set<String> = ["/bridge/poll"]

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        let shouldLog = !skipPaths.contains(path)

        let clientIP = request.headers.first(name: "X-Forwarded-For")
            ?? request.remoteAddress?.ipAddress
            ?? "?"

        let startTime = Date()

        if shouldLog {
            LogManager.shared.log("→ \(request.method) \(path)  [\(clientIP)]", type: .request)
        }

        do {
            let response = try await next.respond(to: request)
            if shouldLog {
                let ms = Int(Date().timeIntervalSince(startTime) * 1000)
                let ok = response.status.code < 400
                LogManager.shared.log("← \(response.status.code) \(ms)ms", type: ok ? .success : .error)
            }
            return response
        } catch {
            let ms = Int(Date().timeIntervalSince(startTime) * 1000)
            LogManager.shared.log("✗ \(path) error: \(error) (\(ms)ms)", type: .error)
            throw error
        }
    }
}
