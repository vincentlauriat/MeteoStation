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

    func save() {
        lastSave = Date()
        let snapshot = readings
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
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
