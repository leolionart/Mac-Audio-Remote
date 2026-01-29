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
        print("[HTTPServer] Starting on port \(port)")

        if !NetworkService.isPortAvailable(port: port) {
             print("⚠️ Port \(port) not available, attempting auto-cleanup...")
             if NetworkService.killAudioRemoteOnPort(port: port) {
                 print("✅ Cleanup successful")
             } else {
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
        print("HTTP server started on port \(port)")
    }

    func stop() async {
        guard isRunning else { return }
        restartTask?.cancel()
        try? await app?.asyncShutdown()
        app = nil
        isRunning = false
        print("HTTP server stopped")
    }

    private func configureRoutes(_ app: Application) {
        app.middleware.use(CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin]
        )))

        // MARK: - Legacy iOS Endpoints

        app.post("toggle-mic") { [weak self] req throws -> ToggleResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            let muted = self.bridgeManager.toggle()
            self.settingsManager.incrementRequestCount()
            return ToggleResponse(status: "ok", muted: muted)
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
            return ToggleResponse(status: "updated", muted: body.muted)
        }

        // Long-polling endpoint for extension
        app.get("bridge", "poll") { [weak self] req async throws -> BridgeEventResponse in
            guard let self = self else { throw Abort(.internalServerError) }

            // Wait for next event (suspends request until event occurs)
            let event = await self.bridgeManager.waitForNextEvent()
            return BridgeEventResponse(event: event.rawValue)
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

enum HTTPServerError: Error {
    case portNotAvailable(Int)
}
