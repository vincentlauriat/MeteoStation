import Foundation

/// Capteur additionnel (canal thermo/hygro, sonde de sol…) détecté dans la requête.
struct ChannelReading: Codable, Equatable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    var temperatureC: Double? = nil
    var humidity: Double? = nil
    var moisturePercent: Double? = nil
}

/// Une mesure complète poussée par la station, convertie en unités métriques.
/// Le dictionnaire `raw` conserve tous les paramètres reçus, y compris ceux
/// qui ne sont pas mappés — le firmware exact varie selon les modèles.
struct WeatherReading: Codable, Equatable {
    var date: Date

    var tempC: Double? = nil
    var humidity: Double? = nil
    var dewPointC: Double? = nil
    var windChillC: Double? = nil
    var heatIndexC: Double? = nil

    var windDirDegrees: Double? = nil
    var windSpeedKmh: Double? = nil
    var windGustKmh: Double? = nil

    var rainRateMmPerHour: Double? = nil
    var rainDayMm: Double? = nil
    var rainWeekMm: Double? = nil
    var rainMonthMm: Double? = nil
    var rainYearMm: Double? = nil

    var uvIndex: Double? = nil
    var solarRadiation: Double? = nil

    var pressureHpa: Double? = nil

    var indoorTempC: Double? = nil
    var indoorHumidity: Double? = nil

    var lowBattery: Bool = false
    var channels: [ChannelReading] = []
    var raw: [String: String] = [:]
}

extension WeatherReading {

    /// Construit une mesure depuis les paramètres d'un upload au format
    /// Weather Underground (unités impériales). Retourne nil si la requête
    /// ne contient aucune donnée météo reconnaissable.
    init?(wuParams: [String: String], date: Date = Date()) {
        var lower: [String: String] = [:]
        for (k, v) in wuParams { lower[k.lowercased()] = v }

        func num(_ key: String) -> Double? {
            guard let s = lower[key], let v = Double(s) else { return nil }
            return v
        }
        func f2c(_ key: String) -> Double? { num(key).map { ($0 - 32) / 1.8 } }
        func mph2kmh(_ key: String) -> Double? { num(key).map { $0 * 1.609344 } }
        func in2mm(_ key: String) -> Double? { num(key).map { $0 * 25.4 } }
        func inhg2hpa(_ key: String) -> Double? { num(key).map { $0 * 33.8639 } }

        self.init(date: date)
        raw = wuParams

        tempC = f2c("tempf")
        humidity = num("humidity")
        dewPointC = f2c("dewptf")
        windChillC = f2c("windchillf")
        heatIndexC = f2c("heatindexf") ?? f2c("heatindex")

        windDirDegrees = num("winddir")
        windSpeedKmh = mph2kmh("windspeedmph")
        windGustKmh = mph2kmh("windgustmph")

        rainRateMmPerHour = in2mm("rainin")
        rainDayMm = in2mm("dailyrainin")
        rainWeekMm = in2mm("weeklyrainin")
        rainMonthMm = in2mm("monthlyrainin")
        rainYearMm = in2mm("yearlyrainin") ?? in2mm("totalrainin")

        uvIndex = num("uv")
        solarRadiation = num("solarradiation")

        pressureHpa = inhg2hpa("baromin") ?? inhg2hpa("absbaromin")

        indoorTempC = f2c("indoortempf")
        indoorHumidity = num("indoorhumidity")

        if let batt = lower["lowbatt"] ?? lower["lowbat"] {
            lowBattery = batt == "1" || batt.lowercased() == "true"
        }

        channels = Self.extractChannels(from: lower)

        let hasData = tempC != nil || pressureHpa != nil || indoorTempC != nil
            || windSpeedKmh != nil || !channels.isEmpty
        if !hasData { return nil }
    }

    /// Capteurs additionnels : temp1f/humidity1 (canaux thermo/hygro),
    /// soiltempNf/soilmoistureN (sondes de sol).
    private static func extractChannels(from lower: [String: String]) -> [ChannelReading] {
        var byKey: [String: ChannelReading] = [:]

        func channel(_ key: String, _ label: String) -> ChannelReading {
            byKey[key] ?? ChannelReading(key: key, label: label)
        }
        func f2c(_ s: String?) -> Double? { s.flatMap(Double.init).map { ($0 - 32) / 1.8 } }

        for (key, value) in lower {
            if let n = key.captureInt(pattern: #"^temp(\d+)f$"#) {
                var ch = channel("ch\(n)", "Canal \(n)")
                ch.temperatureC = f2c(value)
                byKey[ch.key] = ch
            } else if let n = key.captureInt(pattern: #"^humidity(\d+)$"#) {
                var ch = channel("ch\(n)", "Canal \(n)")
                ch.humidity = Double(value)
                byKey[ch.key] = ch
            } else if let n = key.captureInt(pattern: #"^soiltemp(\d*)f$"#, emptyAs: 1) {
                var ch = channel("soil\(n)", "Sol \(n)")
                ch.temperatureC = f2c(value)
                byKey[ch.key] = ch
            } else if let n = key.captureInt(pattern: #"^soilmoist(?:ure)?(\d*)$"#, emptyAs: 1) {
                var ch = channel("soil\(n)", "Sol \(n)")
                ch.moisturePercent = Double(value)
                byKey[ch.key] = ch
            }
        }
        return byKey.values.sorted { $0.key < $1.key }
    }
}

private extension String {
    /// Retourne le premier groupe capturé converti en Int, ou `emptyAs` si le
    /// groupe est vide, ou nil si le motif ne correspond pas.
    func captureInt(pattern: String, emptyAs: Int? = nil) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self)
        else { return nil }
        let captured = String(self[range])
        if captured.isEmpty { return emptyAs }
        return Int(captured)
    }
}
