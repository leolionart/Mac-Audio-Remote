import Foundation

// MARK: - Log Entry

enum LogType {
    case info, success, error, request, warning
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - Log Manager

class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var entries: [LogEntry] = []
    private let maxEntries = 300
    private let queue = DispatchQueue(label: "com.audioremote.logmanager")

    private init() {
        log("LogManager initialized", type: .info)
    }

    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)
        // Dispatch to main thread for @Published update
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
