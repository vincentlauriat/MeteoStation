import Foundation

enum MoonPhase: Int, CaseIterable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, lastQuarter, waningCrescent

    private static let synodicMonth = 29.530588861
    /// Nouvelle lune de référence : 2000-01-06 18:14 UTC.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    static func current(on date: Date = Date()) -> MoonPhase {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        let index = Int((age / synodicMonth * 8).rounded()) % 8
        return MoonPhase(rawValue: index) ?? .newMoon
    }

    var symbolName: String {
        switch self {
        case .newMoon: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .fullMoon: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        }
    }

    var frenchName: String {
        switch self {
        case .newMoon: return "Nouvelle lune"
        case .waxingCrescent: return "Premier croissant"
        case .firstQuarter: return "Premier quartier"
        case .waxingGibbous: return "Gibbeuse croissante"
        case .fullMoon: return "Pleine lune"
        case .waningGibbous: return "Gibbeuse décroissante"
        case .lastQuarter: return "Dernier quartier"
        case .waningCrescent: return "Dernier croissant"
        }
    }
}
