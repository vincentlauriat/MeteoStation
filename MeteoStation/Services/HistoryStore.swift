import Foundation

/// Persistance de l'historique des mesures (JSON dans Application Support),
/// rétention 7 jours, sauvegarde throttlée.
/// Accédé uniquement depuis le main actor ; l'écriture disque part d'un
/// instantané par valeur, d'où le @unchecked Sendable.
final class HistoryStore: @unchecked Sendable {
    private(set) var readings: [WeatherReading] = []

    private let retention: TimeInterval = 7 * 24 * 3600
    private let saveInterval: TimeInterval = 120
    private var lastSave: Date = .distantPast
    private let ioQueue = DispatchQueue(label: "com.vincentlauriat.meteostation.history-io", qos: .utility)

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MeteoStation", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([WeatherReading].self, from: data)
        else { return }
        readings = saved
        prune()
    }

    func append(_ reading: WeatherReading) {
        readings.append(reading)
        prune()
        if Date().timeIntervalSince(lastSave) > saveInterval {
            save()
        }
    }

    /// Ajoute un lot de mesures (relais, rattrapage) : ignore les dates déjà
    /// connues et garde l'historique trié, même si le lot arrive en désordre.
    func merge(_ batch: [WeatherReading]) {
        guard !batch.isEmpty else { return }
        let lastDate = readings.last?.date ?? .distantPast
        let newer = batch.filter { $0.date > lastDate }.sorted { $0.date < $1.date }
        let older = batch.filter { $0.date <= lastDate }
        readings.append(contentsOf: newer)
        if !older.isEmpty {
            // Cas rare (horloge du relais recalée) : insertion triée sans doublon.
            let known = Set(readings.map(\.date))
            let missing = older.filter { !known.contains($0.date) }
            if !missing.isEmpty {
                readings.append(contentsOf: missing)
                readings.sort { $0.date < $1.date }
            }
        }
        prune()
        if Date().timeIntervalSince(lastSave) > saveInterval {
            save()
        }
    }

    func save() {
        lastSave = Date()
        let snapshot = readings
        let url = fileURL
        ioQueue.async {
            Self.write(snapshot, to: url)
        }
    }

    /// Écriture synchrone, pour la fermeture de l'app : une écriture en
    /// arrière-plan serait interrompue par la fin du processus. Passe par la
    /// même file série que `save()`, pour qu'une sauvegarde plus ancienne
    /// encore en cours ne l'écrase pas.
    func saveNow() {
        lastSave = Date()
        let snapshot = readings
        let url = fileURL
        ioQueue.sync {
            Self.write(snapshot, to: url)
        }
    }

    private static func write(_ snapshot: [WeatherReading], to url: URL) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Mesures des dernières `hours` heures (pour les graphes).
    func recent(hours: Double) -> [WeatherReading] {
        let cutoff = Date().addingTimeInterval(-hours * 3600)
        return readings.filter { $0.date >= cutoff }
    }

    /// Mesure la plus proche d'il y a `hoursAgo` heures (pour la tendance).
    func reading(closestTo hoursAgo: Double) -> WeatherReading? {
        let target = Date().addingTimeInterval(-hoursAgo * 3600)
        return readings.min { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-retention)
        if let firstValid = readings.firstIndex(where: { $0.date >= cutoff }), firstValid > 0 {
            readings.removeFirst(firstValid)
        }
    }
}
