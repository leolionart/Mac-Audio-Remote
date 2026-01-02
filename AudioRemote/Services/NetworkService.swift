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
}
