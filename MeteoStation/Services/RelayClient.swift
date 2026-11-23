import Foundation

enum RelayStatus: Equatable {
    case stopped
    case connecting
    case connected
    case unreachable(String)
}

/// Lit les mesures stockées par le relais MeteoStation (Relay/meteorelay.py),
/// typiquement un Raspberry Pi sur le réseau de la station, joint via Tailscale.
///
/// Interroge `GET /readings?since=…` toutes les 5 s. Après une absence (Mac en
/// veille, hors ligne), rattrape l'historique manquant, échantillonné à la minute
/// pour ne pas rapatrier 17 000 mesures par jour.
@MainActor
final class RelayClient {
    struct Item: Decodable {
        let t: Double
        let p: [String: String]
    }

    private struct Page: Decodable {
        let readings: [Item]
        let more: Bool
    }

    /// Mesures reçues, dans l'ordre chronologique, avec la date de réception du relais.
    var onReadings: (([Item]) -> Void)?
    var onStatus: ((RelayStatus) -> Void)?

    private let pollInterval: Duration = .seconds(5)
    private let retryInterval: Duration = .seconds(30)
    /// Au-delà de cet écart, rattrapage échantillonné (une mesure par minute).
    private let catchUpThreshold: TimeInterval = 15 * 60
    private let pageSize = 2000

    private var task: Task<Void, Never>?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// - Parameter since: date de la dernière mesure déjà connue (nil : tout l'historique du relais).
    func start(baseURL: URL, since: @escaping () -> Date?) {
        stop()
        onStatus?(.connecting)
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let ok = await self.poll(baseURL: baseURL, since: since)
                try? await Task.sleep(for: ok ? self.pollInterval : self.retryInterval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        onStatus?(.stopped)
    }

    /// Une passe : enchaîne les pages jusqu'à être à jour. Retourne false si le relais est injoignable.
    private func poll(baseURL: URL, since: () -> Date?) async -> Bool {
        while !Task.isCancelled {
            let after = since()?.timeIntervalSince1970 ?? 0
            let gap = Date().timeIntervalSince1970 - after
            let step = gap > catchUpThreshold ? 60 : 0

            guard var components = URLComponents(url: baseURL.appendingPathComponent("readings"),
                                                 resolvingAgainstBaseURL: false)
            else {
                onStatus?(.unreachable("URL du relais invalide"))
                return false
            }
            components.queryItems = [
                URLQueryItem(name: "since", value: String(format: "%.6f", after)),
                URLQueryItem(name: "limit", value: String(pageSize)),
                URLQueryItem(name: "step", value: String(step)),
            ]
            guard let url = components.url else {
                onStatus?(.unreachable("URL du relais invalide"))
                return false
            }

            let page: Page
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    onStatus?(.unreachable("HTTP \(http.statusCode)"))
                    return false
                }
                page = try JSONDecoder().decode(Page.self, from: data)
            } catch is CancellationError {
                return true
            } catch {
                if Task.isCancelled { return true }
                onStatus?(.unreachable(error.localizedDescription))
                return false
            }

            onStatus?(.connected)
            if !page.readings.isEmpty { onReadings?(page.readings) }
            // Page échantillonnée pleine ou suite annoncée : continuer. Sinon on est à jour.
            if !page.more && step == 0 { return true }
            if page.readings.isEmpty { return true }
        }
        return true
    }
}
