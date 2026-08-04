import Foundation
import Network

enum ListenerStatus: Equatable {
    case stopped
    case starting
    case listening(UInt16)
    case failed(String)
}

/// Mini serveur HTTP recevant les uploads de la station Bresser
/// (format Weather Underground : GET /weatherstation/updateweatherstation.php?…).
/// Accepte aussi un POST form-urlencoded ou JSON par tolérance de firmware.
final class StationListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.vincentlauriat.meteostation.listener")
    private var listener: NWListener?

    var onReading: (@Sendable (_ params: [String: String], _ rawRequest: String) -> Void)?
    var onStatus: (@Sendable (ListenerStatus) -> Void)?

    func start(port: UInt16) {
        queue.async { self.startOnQueue(port: port) }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.onStatus?(.stopped)
        }
    }

    private func startOnQueue(port: UInt16) {
        listener?.cancel()
        listener = nil
        onStatus?(.starting)

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onStatus?(.failed("Port invalide : \(port)"))
            return
        }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: nwPort)
            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.onStatus?(.listening(port))
                case .failed(let error): self?.onStatus?(.failed(error.localizedDescription))
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] connection in
                guard let self else { connection.cancel(); return }
                connection.start(queue: self.queue)
                self.receive(connection, buffer: Data())
            }
            l.start(queue: queue)
            listener = l
        } catch {
            onStatus?(.failed(error.localizedDescription))
        }
    }

    // MARK: - Lecture de la requête

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer[..<headerEnd.lowerBound]
                let header = String(decoding: headerData, as: UTF8.self)
                let expectedBody = Self.contentLength(in: header)
                let bodyReceived = buffer.count - headerEnd.upperBound
                if bodyReceived >= expectedBody {
                    let body = buffer[headerEnd.upperBound...].prefix(expectedBody)
                    self.process(connection, header: header, body: Data(body))
                    return
                }
            }
            if isComplete || error != nil || buffer.count > 512 * 1024 {
                connection.cancel()
            } else {
                self.receive(connection, buffer: buffer)
            }
        }
    }

    private static func contentLength(in header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }

    // MARK: - Traitement et réponse

    private func process(_ connection: NWConnection, header: String, body: Data) {
        defer { respond(connection) }

        let requestLine = header.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        let method = String(parts[0]).uppercased()
        let target = String(parts[1])

        var params = Self.queryParams(fromTarget: target)
        if method == "POST", !body.isEmpty {
            let bodyString = String(decoding: body, as: UTF8.self)
            if bodyString.first == "{" {
                params.merge(Self.flattenJSON(body)) { _, new in new }
            } else {
                params.merge(Self.queryParams(fromTarget: "/?" + bodyString)) { _, new in new }
            }
        }
        guard !params.isEmpty else { return }

        let rawRequest = method == "POST" && !body.isEmpty
            ? requestLine + "\n" + String(decoding: body, as: UTF8.self)
            : requestLine
        onReading?(params, rawRequest)
    }

    private static func queryParams(fromTarget target: String) -> [String: String] {
        guard let components = URLComponents(string: "http://station" + target),
              let items = components.queryItems
        else { return [:] }
        var params: [String: String] = [:]
        for item in items { params[item.name] = item.value ?? "" }
        return params
    }

    private static func flattenJSON(_ data: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var params: [String: String] = [:]
        for (key, value) in object {
            switch value {
            case let s as String: params[key] = s
            case let n as NSNumber: params[key] = n.stringValue
            default: break
            }
        }
        return params
    }

    private func respond(_ connection: NWConnection) {
        let body = "success"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
