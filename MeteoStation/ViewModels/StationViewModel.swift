import AppKit
import Foundation
import SwiftUI

enum PressureTrend {
    case rising, steady, falling

    var symbolName: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .steady: return "arrow.right"
        case .falling: return "arrow.down.right"
        }
    }
}

/// Prévision simple façon console, dérivée de la tendance barométrique sur 3 h.
enum Forecast {
    case sunny, partlyCloudy, rainy, stormy

    var symbolName: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.heavyrain.fill"
        }
    }

    var label: String {
        switch self {
        case .sunny: return "Ensoleillé"
        case .partlyCloudy: return "Variable"
        case .rainy: return "Pluvieux"
        case .stormy: return "Orageux"
        }
    }
}

struct PressurePoint: Identifiable {
    let id = UUID()
    let date: Date
    let hpa: Double
}

@MainActor
final class StationViewModel: ObservableObject {
    @Published private(set) var current: WeatherReading?
    @Published private(set) var status: ListenerStatus = .stopped
    @Published private(set) var lastReceived: Date?
    @Published private(set) var lastRawRequest = ""
    @Published private(set) var pressureChart: [PressurePoint] = []

    @Published var demoMode = false {
        didSet { if demoMode { applyDemo() } else if isDemoData { clearDemo() } }
    }

    @Published var port: Int {
        didSet {
            guard port != oldValue else { return }
            UserDefaults.standard.set(port, forKey: "listenPort")
            restartListener()
        }
    }

    @Published var channelIndex = 0

    private let listener = StationListener()
    private let store = HistoryStore()
    private var isDemoData = false

    /// Capteur additionnel affiché dans la zone IN (bouton CHANNEL).
    var selectedChannel: ChannelReading? {
        guard let channels = current?.channels, !channels.isEmpty else { return nil }
        return channels[min(channelIndex, channels.count - 1)]
    }

    func cycleChannel() {
        guard let count = current?.channels.count, count > 0 else { return }
        channelIndex = (channelIndex + 1) % count
    }

    /// Tendance d'une grandeur vs il y a `hours` heures (flèches de la console).
    func trend(of keyPath: KeyPath<WeatherReading, Double?>,
               hours: Double = 1, threshold: Double) -> PressureTrend? {
        guard store.readings.count > 1,
              let now = current?[keyPath: keyPath],
              let before = store.reading(closestTo: hours)?[keyPath: keyPath]
        else { return nil }
        let delta = now - before
        if delta > threshold { return .rising }
        if delta < -threshold { return .falling }
        return .steady
    }

    struct TodayStats {
        var tempMin: Double?
        var tempMax: Double?
        var humidityMin: Double?
        var humidityMax: Double?
        var gustMax: Double?
        var pressureMin: Double?
        var pressureMax: Double?
    }

    /// Min/max du jour (bouton MAX/MIN de la console).
    var todayStats: TodayStats {
        let calendar = Calendar.current
        var today = store.readings.filter { calendar.isDateInToday($0.date) }
        if let current, calendar.isDateInToday(current.date) { today.append(current) }
        let temps = today.compactMap(\.tempC)
        let hums = today.compactMap(\.humidity)
        let gusts = today.compactMap(\.windGustKmh)
        let pressures = today.compactMap(\.pressureHpa)
        return TodayStats(tempMin: temps.min(), tempMax: temps.max(),
                          humidityMin: hums.min(), humidityMax: hums.max(),
                          gustMax: gusts.max(),
                          pressureMin: pressures.min(), pressureMax: pressures.max())
    }

    var localIP: String { NetworkInfo.primaryIPv4() ?? "IP introuvable" }

    var pressureTrend: PressureTrend? {
        guard let now = current?.pressureHpa,
              let before = store.reading(closestTo: 3)?.pressureHpa,
              store.readings.count > 1
        else { return isDemoData ? .steady : nil }
        let delta = now - before
        if delta > 1 { return .rising }
        if delta < -1 { return .falling }
        return .steady
    }

    var forecast: Forecast {
        guard let trend = pressureTrend else { return .partlyCloudy }
        switch trend {
        case .rising: return .sunny
        case .steady: return .partlyCloudy
        case .falling:
            if let now = current?.pressureHpa, now < 1000 { return .stormy }
            return .rainy
        }
    }

    init() {
        let saved = UserDefaults.standard.integer(forKey: "listenPort")
        port = (1...65535).contains(saved) ? saved : 8642

        store.load()
        if let last = store.readings.last {
            current = last
            lastReceived = last.date
        }
        refreshChart()

        listener.onReading = { [weak self] params, raw in
            Task { @MainActor in self?.ingest(params: params, raw: raw) }
        }
        listener.onStatus = { [weak self] status in
            Task { @MainActor in self?.status = status }
        }
        listener.start(port: UInt16(port))

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [store] _ in
            store.save()
        }
    }

    func restartListener() {
        guard (1...65535).contains(port) else { return }
        listener.start(port: UInt16(port))
    }

    private func ingest(params: [String: String], raw: String) {
        lastRawRequest = raw
        guard let reading = WeatherReading(wuParams: params) else { return }
        if isDemoData {
            demoMode = false
            isDemoData = false
        }
        current = reading
        lastReceived = reading.date
        store.append(reading)
        refreshChart()
    }

    private func refreshChart() {
        pressureChart = store.recent(hours: 24).compactMap { reading in
            reading.pressureHpa.map { PressurePoint(date: reading.date, hpa: $0) }
        }
    }

    // MARK: - Mode démo (aperçu du look tant que la station n'envoie rien)

    private func applyDemo() {
        guard store.readings.isEmpty || current == nil || isDemoData else {
            // De vraies données existent déjà : ne pas les écraser.
            demoMode = false
            return
        }
        isDemoData = true
        var demo = WeatherReading(date: Date())
        demo.tempC = 21.4
        demo.humidity = 58
        demo.dewPointC = 12.9
        demo.windChillC = 21.4
        demo.windDirDegrees = 225
        demo.windSpeedKmh = 11.2
        demo.windGustKmh = 18.7
        demo.rainRateMmPerHour = 0
        demo.rainDayMm = 2.4
        demo.rainWeekMm = 8.6
        demo.rainMonthMm = 24.2
        demo.rainYearMm = 412
        demo.uvIndex = 5
        demo.solarRadiation = 612
        demo.pressureHpa = 1017.2
        demo.indoorTempC = 23.1
        demo.indoorHumidity = 47
        demo.channels = [
            ChannelReading(key: "ch1", label: "Canal 1", temperatureC: 18.2, humidity: 61, moisturePercent: nil),
            ChannelReading(key: "ch2", label: "Canal 2", temperatureC: 16.9, humidity: 72, moisturePercent: nil),
            ChannelReading(key: "soil1", label: "Sol 1", temperatureC: 17.5, humidity: nil, moisturePercent: 34),
        ]
        current = demo
        lastReceived = demo.date

        let now = Date()
        pressureChart = stride(from: -24.0, through: 0, by: 0.25).map { hours in
            PressurePoint(date: now.addingTimeInterval(hours * 3600),
                          hpa: 1015 + 3 * sin((hours + 24) / 6))
        }
    }

    private func clearDemo() {
        isDemoData = false
        current = nil
        lastReceived = nil
        refreshChart()
    }
}
