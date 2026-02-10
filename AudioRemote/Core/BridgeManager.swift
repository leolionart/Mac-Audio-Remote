import Foundation
import Combine

/// Events that can be broadcasted to extensions
enum BridgeEvent: String, Codable {
    case toggleMic = "toggle-mic"
    case muteMic = "mute-mic"
    case unmuteMic = "unmute-mic"
    case toggleSpeaker = "toggle-speaker"
    case volumeUp = "volume-up"
    case volumeDown = "volume-down"
}

/// Represents an audio input device (simplified for backward compat)
struct AudioInputDevice: Identifiable, Equatable {
    let id: UInt32 = 0
    let name: String
    let uid: String

    static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

/// Manages the state and communication between macOS native app and Chrome Extension
class BridgeManager: ObservableObject {
    // Singleton shared instance
    static let shared = BridgeManager()

    // MARK: - Published State (UI Binding)
    @Published var isMuted: Bool = false
    @Published var currentVolume: Float32 = 0.0
    @Published var outputVolume: Float32 = 0.5
    @Published var isOutputMuted: Bool = false

    @Published var currentInputDeviceName: String = "Chrome Bridge"
    @Published var availableInputDevices: [AudioInputDevice] = []

    // Backward compatibility properties (unused but kept for compilation if needed)
    var muteMode: MuteMode = .hardwareMute
    var nullDeviceUID: String?
    var realMicDeviceUID: String?
    var forceChannelMute: Bool = true

    // MARK: - Event Handling
    private var eventContinuations: [CheckedContinuation<BridgeEvent, Never>] = []
    private let eventQueue = DispatchQueue(label: "com.audioremote.bridge.events")

    // MARK: - Confirmation Handling
    private var confirmationContinuations: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private let confirmationQueue = DispatchQueue(label: "com.audioremote.bridge.confirmations")

    init() {
        print("BridgeManager initialized - operating in Chrome Extension Bridge mode")
        // Initialize mock devices list for UI
        self.availableInputDevices = [
            AudioInputDevice(name: "Google Meet Extension", uid: "com.google.meet"),
            AudioInputDevice(name: "Zoom Extension", uid: "us.zoom.xos")
        ]
    }

    // MARK: - Public Methods

    /// Toggle microphone mute state (legacy - no confirmation)
    @discardableResult
    func toggle() -> Bool {
        // Optimistic update
        let newState = !isMuted
        updateMicState(muted: newState)

        // Broadcast specific event for granular control
        broadcast(event: newState ? .muteMic : .unmuteMic)

        // Broadcast generic toggle
        broadcast(event: .toggleMic)

        return newState
    }

    /// Toggle microphone with confirmation from extension
    /// - Parameter timeout: Timeout in seconds (default 3)
    /// - Returns: True if successfully muted, false on timeout
    func toggleWithConfirmation(timeout: TimeInterval = 3.0) async -> Bool {
        let requestId = UUID()
        let expectedState = !isMuted

        // Create confirmation continuation BEFORE broadcasting
        let confirmation = await withCheckedContinuation { continuation in
            confirmationQueue.sync {
                confirmationContinuations[requestId] = continuation
            }

            // Broadcast event
            broadcast(event: expectedState ? .muteMic : .unmuteMic)
            broadcast(event: .toggleMic)

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                confirmationQueue.sync {
                    if let cont = confirmationContinuations.removeValue(forKey: requestId) {
                        print("⚠️ Confirmation timeout for request \(requestId)")
                        cont.resume(returning: false)
                    }
                }
            }
        }

        return confirmation
    }

    /// Called when extension reports actual state change
    /// - Parameter muted: The actual mute state from extension
    /// - Returns: True if this was a confirmation response
    @discardableResult
    func updateMicState(muted: Bool) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.isMuted = muted
            self?.currentVolume = muted ? 0.0 : 1.0
            print("Bridge state updated: \(muted ? "Muted" : "Unmuted")")
        }

        // Resume any waiting confirmations
        var resumedAny = false
        confirmationQueue.sync {
            for (id, continuation) in confirmationContinuations {
                print("✅ Confirmation received for request \(id)")
                continuation.resume(returning: true)
                resumedAny = true
            }
            confirmationContinuations.removeAll()
        }

        return resumedAny
    }

    func setOutputVolume(_ volume: Float32) {
        DispatchQueue.main.async { [weak self] in
            self?.outputVolume = volume
        }
        // Could forward to system volume if desired, but for now focusing on Meet
    }

    func increaseOutputVolume(_ amount: Float32 = 0.1) {
        broadcast(event: .volumeUp)
        // Mock UI update
        let newVol = min(1.0, outputVolume + amount)
        setOutputVolume(newVol)
    }

    func decreaseOutputVolume(_ amount: Float32 = 0.1) {
        broadcast(event: .volumeDown)
        // Mock UI update
        let newVol = max(0.0, outputVolume - amount)
        setOutputVolume(newVol)
    }

    @discardableResult
    func toggleOutputMute() -> Bool {
        let newState = !isOutputMuted
        DispatchQueue.main.async { [weak self] in
            self?.isOutputMuted = newState
        }
        broadcast(event: .toggleSpeaker)
        return newState
    }

    // MARK: - Bridge Communication

    /// Broadcast event to all waiting long-pollers
    func broadcast(event: BridgeEvent) {
        print("📢 Bridge Event: \(event.rawValue)")
        eventQueue.sync {
            // Resume all waiting continuations
            for continuation in eventContinuations {
                continuation.resume(returning: event)
            }
            eventContinuations.removeAll()
        }
    }

    /// Wait for next event (Async Long-polling)
    func waitForNextEvent() async -> BridgeEvent {
        return await withCheckedContinuation { continuation in
            eventQueue.async { [weak self] in
                self?.eventContinuations.append(continuation)
            }
        }
    }

    // MARK: - Deprecated/Compat Methods
    // Keeping these to minimize changes in other files during transition

    func refreshInputDevices() {
        // No-op
    }

    func getVolume() -> Float32 {
        return isMuted ? 0.0 : 1.0
    }

    func getOutputVolume() -> Float32 {
        return outputVolume
    }
}
