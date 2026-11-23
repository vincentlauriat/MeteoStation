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
/// Interroge `GET /readings` toutes les 5 s. Le curseur est l'identifiant de la
/// dernière mesure reçue du relais (`after_id`), indépendant du décodage, du
/// dédoublonnage et de la purge côté app : il avance à chaque page non vide, la
/// boucle de pagination ne peut donc pas tourner sur place. Seule la première
/// requête part d'une date (la dernière mesure déjà connue localement).
/// Après une absence de plus de 15 min, le rattrapage est échantillonné à la
/// minute pour ne pas rapatrier 17 000 mesures par jour.
@MainActor
final class RelayClient {
    struct Item: Decodable {
        let id: Int
        let t: Double
        let p: [String: String]
    }

    private struct Page: Decodable {
        let readings: [Item]
        let more: Bool
    }

    /// Mesures reçues, dans l'ordre d'arrivée sur le relais, horodatées par le relais.
    var onReadings: (([Item]) -> Void)?
    var onStatus: ((RelayStatus) -> Void)?

    private let pollInterval: Duration = .seconds(5)
    private let retryInterval: Duration = .seconds(30)
    /// Au-delà de cet écart, rattrapage échantillonné (une mesure par minute).
    private let catchUpThreshold: TimeInterval = 15 * 60
    private let pageSize = 2000

    private var task: Task<Void, Never>?
    private var cursor: Int?
    /// Date (relais) de la dernière mesure reçue, pour décider du rattrapage échantillonné.
    private var lastTime: Double?
    private var lastStatus: RelayStatus = .stopped
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// - Parameter since: date de la dernière mesure déjà connue (nil : tout l'historique du relais).
    func start(baseURL: URL, since: Date?) {
        stop()
        cursor = nil
        lastTime = nil
        setStatus(.connecting)
        let endpoint = Self.readingsEndpoint(baseURL)
        let initialSince = since?.timeIntervalSince1970 ?? 0
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let endpoint else {
                    self?.setStatus(.unreachable("URL du relais invalide"))
                    return
                }
                let ok = await self.poll(endpoint: endpoint, initialSince: initialSince)
                try? await Task.sleep(for: ok ? self.pollInterval : self.retryInterval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        setStatus(.stopped)
    }

    /// Arrête le relais en affichant la raison (ex. adresse manquante).
    func fail(_ message: String) {
        task?.cancel()
        task = nil
        setStatus(.unreachable(message))
    }

    /// `/readings` à la racine de l'hôte, quel que soit le chemin saisi par l'utilisateur.
    private static func readingsEndpoint(_ baseURL: URL) -> URLComponents? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.host != nil
        else { return nil }
        components.path = "/readings"
        components.query = nil
        components.fragment = nil
        return components
    }

    private func setStatus(_ status: RelayStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatus?(status)
    }

    /// Une passe : enchaîne les pages jusqu'à être à jour. Retourne false si le relais est injoignable.
    private func poll(endpoint: URLComponents, initialSince: Double) async -> Bool {
        // Le mode (rattrapage ou direct) est fixé pour toute la passe : échantillonné
        // si la dernière mesure connue date de plus de 15 min (veille, coupure réseau).
        let gap = Date().timeIntervalSince1970 - (lastTime ?? initialSince)
        let step = gap > catchUpThreshold ? 60 : 0

        while !Task.isCancelled {
            var components = endpoint
            var query = [
                URLQueryItem(name: "limit", value: String(pageSize)),
                URLQueryItem(name: "step", value: String(step)),
            ]
            if let cursor {
                query.append(URLQueryItem(name: "after_id", value: String(cursor)))
            } else {
                query.append(URLQueryItem(name: "since", value: String(initialSince)))
            }
            components.queryItems = query
            guard let url = components.url else {
                setStatus(.unreachable("URL du relais invalide"))
                return false
            }

            let page: Page
            do {
                let (data, response) = try await session.data(from: url)
                // Arrêté ou redémarré pendant la requête : ne rien livrer.
                if Task.isCancelled { return true }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    setStatus(.unreachable(http.statusCode == 403
                        ? "HTTP 403 (passer par Tailscale ou activer la lecture LAN du relais)"
                        : "HTTP \(http.statusCode)"))
                    return false
                }
                page = try JSONDecoder().decode(Page.self, from: data)
            } catch {
                if Task.isCancelled { return true }
                setStatus(.unreachable(error.localizedDescription))
                return false
            }

            setStatus(.connected)
            guard let lastID = page.readings.last?.id else { return true }
            if let cursor, lastID <= cursor { return true }  // garde-fou : jamais sur place
            cursor = lastID
            lastTime = page.readings.last?.t
            onReadings?(page.readings)
            if !page.more { return true }
        }
        return true
    }
}
