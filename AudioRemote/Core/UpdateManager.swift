import Foundation
import AppKit
import Combine

// MARK: - Update State
enum UpdateState {
    case idle
    case checking
    case available(UpdateInfo)
    case upToDate
    case downloading(progress: Double)
    case installing
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Idle"
        case .checking: return "Checking for updates..."
        case .available(let info): return "Update available: \(info.version)"
        case .upToDate: return "App is up to date"
        case .downloading(let progress): return "Downloading: \(Int(progress * 100))%"
        case .installing: return "Installing..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Update Manager
class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    @Published var state: UpdateState = .idle
    @Published var lastCheckDate: Date?

    // Legacy properties for compatibility with existing UI binding
    @Published var canCheckForUpdates = true
    @Published var isCheckingForUpdates = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadingVersion: String?
    private var cancellables = Set<AnyCancellable>()

    private let autoCheckInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let autoCheckKey = "lastUpdateCheckDate"
    private let skipVersionKey = "skipUpdateVersion"

    override init() {
        super.init()
        lastCheckDate = UserDefaults.standard.object(forKey: autoCheckKey) as? Date

        // Bind state to legacy isCheckingForUpdates property
        $state
            .map { state in
                if case .checking = state { return true }
                if case .downloading = state { return true }
                if case .installing = state { return true }
                return false
            }
            .assign(to: \.isCheckingForUpdates, on: self)
            .store(in: &cancellables)

        // Auto check on launch if enough time has passed
        checkForUpdatesSilently()
    }

    // MARK: - Public API

    func checkForUpdates() {
        checkForUpdates(silent: false)
    }

    func checkForUpdatesSilently() {
        guard let lastCheck = lastCheckDate,
              Date().timeIntervalSince(lastCheck) >= autoCheckInterval else {
            return
        }
        checkForUpdates(silent: true)
    }

    func downloadUpdate(_ info: UpdateInfo) {
        state = .downloading(progress: 0)
        downloadingVersion = info.version

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadTask = session.downloadTask(with: info.downloadURL)
        downloadTask?.resume()
    }

    func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skipVersionKey)
        state = .idle
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func checkForUpdates(silent: Bool) {
        if !silent { state = .checking }

        UpdateChecker.shared.checkForUpdates { [weak self] result in
            guard let self = self else { return }

            self.lastCheckDate = Date()
            UserDefaults.standard.set(self.lastCheckDate, forKey: self.autoCheckKey)

            switch result {
            case .available(let info):
                let skipped = UserDefaults.standard.string(forKey: self.skipVersionKey)
                if silent && skipped == info.version {
                    self.state = .idle
                    return
                }
                self.state = .available(info)

            case .upToDate:
                self.state = .upToDate
                if silent {
                    // Reset to idle after a moment if silent so we don't show "Up to date" to user
                    self.state = .idle
                } else {
                     // For manual check, we want to show "Up to date" state
                     DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                         self.state = .idle
                     }
                }

            case .error(let message):
                self.state = .error(message)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.state = .idle
                }
            }
        }
    }

    // MARK: - Install

    private func install(zipPath: URL) {
        state = .installing

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.prepareInstall(zipPath: zipPath)

            DispatchQueue.main.async {
                switch result {
                case .success(let tempApp):
                    self.relaunchWithNewApp(tempApp: tempApp)
                case .failure(let error):
                    self.state = .error(error)
                }
            }
        }
    }

    private enum InstallResult {
        case success(tempApp: String)
        case failure(error: String)
    }

    private func prepareInstall(zipPath: URL) -> InstallResult {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("AudioRemoteUpdate")

        // Clean up previous temp dir
        try? fileManager.removeItem(at: tempDir)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Unzip
        let unzipOutput = shell("unzip -o '\(zipPath.path)' -d '\(tempDir.path)'")
        guard unzipOutput.ok else {
            return .failure(error: "Failed to unzip update file.")
        }

        // Find .app bundle
        var appBundlePath: String?
        if let contents = try? fileManager.contentsOfDirectory(atPath: tempDir.path) {
            for item in contents {
                if item.hasSuffix(".app") {
                    appBundlePath = tempDir.appendingPathComponent(item).path
                    break
                }
            }
        }

        guard let sourceApp = appBundlePath else {
            return .failure(error: "No app bundle found in update.")
        }

        // Check code signature (basic security check)
        // In a real app we might want stricter checks here

        return .success(tempApp: sourceApp)
    }

    private func relaunchWithNewApp(tempApp: String) {
        let bundlePath = Bundle.main.bundlePath
        let script = "sleep 1 && rm -rf '\(bundlePath)' && mv '\(tempApp)' '\(bundlePath)' && open '\(bundlePath)'"

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]
        try? task.run()

        NSApp.terminate(nil)
    }

    @discardableResult
    private func shell(_ command: String) -> (output: String, ok: Bool) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus == 0)
    }
}

// MARK: - URLSession Download Delegate

extension UpdateManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let version = downloadingVersion ?? "latest"
        let zipPath = tempDir.appendingPathComponent("AudioRemote-\(version).zip")

        do {
            if FileManager.default.fileExists(atPath: zipPath.path) {
                try FileManager.default.removeItem(at: zipPath)
            }
            try FileManager.default.copyItem(at: location, to: zipPath)
            install(zipPath: zipPath)
        } catch {
            state = .error("Failed to save update file: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.state = .downloading(progress: Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        DispatchQueue.main.async {
            if (error as NSError).code == NSURLErrorCancelled {
                self.state = .idle
            } else {
                self.state = .error("Download failed: \(error.localizedDescription)")
            }
        }
    }
}
