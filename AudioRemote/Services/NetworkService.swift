import Foundation

class NetworkService {
    static func getLocalIP() -> String {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            print("Failed to get network interfaces")
            return address
        }

        guard let firstAddr = ifaddr else {
            return address
        }

        defer {
            freeifaddrs(ifaddr)
        }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            // Check for running IPv4, non-loopback interface
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING),
               addr.sa_family == UInt8(AF_INET) {

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(ptr.pointee.ifa_addr,
                           socklen_t(addr.sa_len),
                           &hostname,
                           socklen_t(hostname.count),
                           nil,
                           socklen_t(0),
                           NI_NUMERICHOST)

                let ipAddress = String(cString: hostname)

                // Skip loopback
                if !ipAddress.hasPrefix("127.") {
                    address = ipAddress
                    break
                }
            }
        }

        return address
    }

    static func isPortAvailable(port: Int) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD != -1 else {
            return false
        }

        defer {
            close(socketFD)
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
    }

    /// Get information about the process using a specific port
    /// Returns (PID, process name) tuple if found, nil otherwise
    static func getProcessUsingPort(port: Int) -> (pid: Int32, name: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", ":\(port)", "-t", "-sTCP:LISTEN"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return nil
            }

            // lsof -t returns PIDs, one per line
            let pids = output.components(separatedBy: .newlines)
                .compactMap { Int32($0) }

            guard let pid = pids.first else {
                return nil
            }

            // Get process name
            let nameProcess = Process()
            nameProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
            nameProcess.arguments = ["-p", "\(pid)", "-o", "comm="]

            let namePipe = Pipe()
            nameProcess.standardOutput = namePipe
            nameProcess.standardError = Pipe()

            try nameProcess.run()
            nameProcess.waitUntilExit()

            let nameData = namePipe.fileHandleForReading.readDataToEndOfFile()
            let processName = String(data: nameData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

            return (pid: pid, name: processName)

        } catch {
            print("⚠️ Error checking process for port \(port): \(error)")
            return nil
        }
    }

    /// Kill process using a specific port (only if it's AudioRemote)
    /// Returns true if process was killed, false otherwise
    @discardableResult
    static func killAudioRemoteOnPort(port: Int) -> Bool {
        guard let processInfo = getProcessUsingPort(port: port) else {
            print("ℹ️ No process found using port \(port)")
            return false
        }

        // Only kill if it's AudioRemote to prevent accidentally killing other apps
        guard processInfo.name.contains("AudioRemote") || processInfo.name.contains("AudioRemo") else {
            print("⚠️ Port \(port) is used by '\(processInfo.name)' (PID: \(processInfo.pid)), not AudioRemote. Won't auto-kill.")
            return false
        }

        print("🔄 Found old AudioRemote instance (PID: \(processInfo.pid)) using port \(port). Cleaning up...")

        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
        killProcess.arguments = ["-9", "\(processInfo.pid)"]

        do {
            try killProcess.run()
            killProcess.waitUntilExit()

            // Wait longer for port to be fully released (increased from 0.5s to 2s)
            Thread.sleep(forTimeInterval: 2.0)

            // Verify multiple times with delay
            var attempts = 0
            let maxAttempts = 10
            while !isPortAvailable(port: port) && attempts < maxAttempts {
                Thread.sleep(forTimeInterval: 0.2)
                attempts += 1
            }

            if isPortAvailable(port: port) {
                print("✅ Successfully cleaned up old instance. Port \(port) is now available.")
                return true
            } else {
                print("⚠️ Port \(port) still not available after cleanup (waited \(2.0 + Double(attempts) * 0.2)s)")
                return false
            }
        } catch {
            print("❌ Failed to kill process \(processInfo.pid): \(error)")
            return false
        }
    }
}
