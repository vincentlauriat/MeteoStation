import Foundation

enum NetworkInfo {
    /// Adresse IPv4 locale du Mac (interface active non-loopback),
    /// à renseigner dans WSLink comme serveur personnalisé.
    static func primaryIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var candidates: [(name: String, address: String)] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                              &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: current.pointee.ifa_name)
            candidates.append((name, String(cString: host)))
        }
        // Priorité aux interfaces classiques WiFi/Ethernet.
        let preferred = ["en0", "en1", "en2"]
        for name in preferred {
            if let match = candidates.first(where: { $0.name == name }) { return match.address }
        }
        return candidates.first?.address
    }
}
