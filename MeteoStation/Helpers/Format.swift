import Foundation

/// Formatage des valeurs pour l'affichage console, locale française,
/// avec bascule métrique/impérial (le modèle est toujours en métrique).
enum Format {
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        return f
    }()

    static func number(_ value: Double, digits: Int = 1) -> String {
        numberFormatter.minimumFractionDigits = digits
        numberFormatter.maximumFractionDigits = digits
        return numberFormatter.string(from: NSNumber(value: value)) ?? "--"
    }

    static func temp(_ celsius: Double?, imperial: Bool) -> String {
        guard let celsius else { return "--" }
        let v = imperial ? celsius * 1.8 + 32 : celsius
        return number(v)
    }

    static func tempUnit(imperial: Bool) -> String { imperial ? "°F" : "°C" }

    static func speed(_ kmh: Double?, imperial: Bool) -> String {
        guard let kmh else { return "--" }
        return number(imperial ? kmh / 1.609344 : kmh)
    }

    static func speedUnit(imperial: Bool) -> String { imperial ? "mph" : "km/h" }

    static func rain(_ mm: Double?, imperial: Bool) -> String {
        guard let mm else { return "--" }
        return imperial ? number(mm / 25.4, digits: 2) : number(mm)
    }

    static func rainUnit(imperial: Bool) -> String { imperial ? "in" : "mm" }

    static func pressure(_ hpa: Double?, imperial: Bool) -> String {
        guard let hpa else { return "--" }
        return imperial ? number(hpa / 33.8639, digits: 2) : number(hpa)
    }

    static func pressureUnit(imperial: Bool) -> String { imperial ? "inHg" : "hPa" }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return number(value, digits: 0)
    }

    static func windDirection(_ degrees: Double?) -> String {
        guard let degrees else { return "--" }
        let sectors = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                       "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return sectors[index]
    }

    /// Secteurs en notation anglaise, comme l'affichage de la console.
    static func windDirectionEN(_ degrees: Double?) -> String {
        guard let degrees else { return "--" }
        let sectors = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                       "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return sectors[index]
    }

    /// Vitesse en m/s (affichage central de la boussole, comme la console).
    static func windMs(_ kmh: Double?) -> String {
        guard let kmh else { return "--" }
        return number(kmh / 3.6)
    }

    static func relativeAge(since date: Date?) -> String {
        guard let date else { return "jamais" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "à l'instant" }
        if seconds < 60 { return "il y a \(seconds) s" }
        if seconds < 3600 { return "il y a \(seconds / 60) min" }
        return "il y a \(seconds / 3600) h"
    }
}
