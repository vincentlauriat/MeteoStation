import Charts
import SwiftUI

/// Petite flèche de tendance à côté d'une valeur, comme sur la console.
struct TrendArrow: View {
    let trend: PressureTrend?

    var body: some View {
        if let trend {
            Image(systemName: trend.symbolName)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(ConsoleTheme.digit.opacity(0.8))
        }
    }
}

/// Antenne de réception : bleue si une trame est arrivée récemment.
struct SignalIcon: View {
    let lastReceived: Date?

    private var isLive: Bool {
        guard let lastReceived else { return false }
        return Date().timeIntervalSince(lastReceived) < 300
    }

    var body: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isLive ? ConsoleTheme.digitBlue : Color.white.opacity(0.2))
    }
}

// MARK: - OUT (extérieur)

struct OutTileView: View {
    @EnvironmentObject private var model: StationViewModel

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PillLabel(text: "Out")
                    Spacer()
                    SignalIcon(lastReceived: model.lastReceived)
                }
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    LCDDigits(value: Format.temp(model.current?.tempC, imperial: false),
                              size: 52, unit: "°C")
                    TrendArrow(trend: model.trend(of: \.tempC, threshold: 0.3))
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    LCDDigits(value: Format.percent(model.current?.humidity),
                              size: 38, color: ConsoleTheme.digitBlue, unit: "%")
                    TrendArrow(trend: model.trend(of: \.humidity, threshold: 2))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - IN (intérieur + canal sélectionné)

struct InTileView: View {
    @EnvironmentObject private var model: StationViewModel

    private var comfortEmoji: String {
        guard let humidity = model.current?.indoorHumidity else { return "" }
        let temp = model.current?.indoorTempC ?? 21
        if (40...60).contains(humidity) && (18...26).contains(temp) { return "🙂" }
        if humidity > 70 || temp > 28 { return "🥵" }
        if humidity < 30 { return "😐" }
        return "☹️"
    }

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PillLabel(text: "In")
                    Spacer()
                    SignalIcon(lastReceived: model.lastReceived)
                }
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    LCDDigits(value: Format.temp(model.current?.indoorTempC, imperial: false),
                              size: 52, unit: "°C")
                    TrendArrow(trend: model.trend(of: \.indoorTempC, threshold: 0.3))
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    LCDDigits(value: Format.percent(model.current?.indoorHumidity),
                              size: 38, color: ConsoleTheme.digitBlue, unit: "%")
                    TrendArrow(trend: model.trend(of: \.indoorHumidity, threshold: 2))
                    Text(comfortEmoji).font(.system(size: 20))
                }
                Spacer(minLength: 0)
                if let channel = model.selectedChannel {
                    Divider().overlay(ConsoleTheme.tileBorder)
                    HStack(spacing: 8) {
                        LCDText(value: "CH\(model.channelIndex + 1)", size: 12,
                                color: ConsoleTheme.digitBlue)
                        Text(channel.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(ConsoleTheme.label)
                        Spacer()
                        if let t = channel.temperatureC {
                            LCDDigits(value: Format.temp(t, imperial: false), size: 15, unit: "°C")
                        }
                        if let h = channel.humidity {
                            LCDDigits(value: Format.percent(h), size: 15,
                                      color: ConsoleTheme.digitBlue, unit: "%")
                        }
                        if let m = channel.moisturePercent {
                            LCDDigits(value: Format.percent(m), size: 15,
                                      color: ConsoleTheme.digitTeal, unit: "%")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - INDEX (ressenti)

struct IndexTileView: View {
    let reading: WeatherReading?

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PillLabel(text: "Index")
                    TechLabel(text: "Feels like")
                }
                Spacer(minLength: 0)
                LCDDigits(value: Format.temp(reading?.windChillC ?? reading?.heatIndexC ?? reading?.tempC,
                                             imperial: false),
                          size: 34, color: ConsoleTheme.digitTeal, unit: "°C")
                HStack(spacing: 6) {
                    TechLabel(text: "Rosée")
                    LCDDigits(value: Format.temp(reading?.dewPointC, imperial: false),
                              size: 14, color: ConsoleTheme.digitTeal, unit: "°C")
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - SUN (UV + rayonnement)

struct SunTileView: View {
    let reading: WeatherReading?

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 6) {
                PillLabel(text: "Sun")
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    TechLabel(text: "UV Index")
                    LCDDigits(value: reading?.uvIndex.map { Format.number($0) } ?? "--",
                              size: 30)
                }
                HStack(spacing: 8) {
                    TechLabel(text: "Solaire")
                    LCDDigits(value: reading?.solarRadiation.map { Format.number($0, digits: 0) } ?? "--",
                              size: 16, unit: "W/m²")
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - FORECAST

struct ForecastTileView: View {
    let forecast: Forecast

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 6) {
                PillLabel(text: "Forecast")
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: forecast.symbolName)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(ConsoleTheme.sun, ConsoleTheme.cloud)
                        .font(.system(size: 46))
                        .shadow(color: ConsoleTheme.cloud.opacity(0.4), radius: 8)
                    Spacer()
                }
                Text(forecast.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConsoleTheme.label)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - DATE (jour + lune)

struct DateTileView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            ScreenSection {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 22) {
                                TechLabel(text: "D")
                                TechLabel(text: "M")
                            }
                            LCDDigits(value: Self.dayMonth(context.date), size: 26)
                        }
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        LCDText(value: Self.weekdayFR(context.date), size: 22)
                        Spacer()
                        VStack(spacing: 2) {
                            TechLabel(text: "Moon")
                            Image(systemName: MoonPhase.current(on: context.date).symbolName)
                                .font(.system(size: 24))
                                .foregroundStyle(ConsoleTheme.digit, Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    private static func dayMonth(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 0)-\(c.month ?? 0)"
    }

    private static func weekdayFR(_ date: Date) -> String {
        let days = ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"]
        return days[(Calendar.current.component(.weekday, from: date) - 1) % 7]
    }
}

// MARK: - TIME (horloge + éphémérides)

struct TimeTileView: View {
    @EnvironmentObject private var model: StationViewModel
    @AppStorage("latitude") private var latitude = 48.8566
    @AppStorage("longitude") private var longitude = 2.3522

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScreenSection {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PillLabel(text: "Time")
                        TechLabel(text: "Sync")
                        SignalIcon(lastReceived: model.lastReceived)
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Spacer()
                        LCDDigits(value: Self.hourMinute(context.date), size: 40)
                        LCDDigits(value: Self.seconds(context.date), size: 20)
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    ephemeris(for: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func ephemeris(for date: Date) -> some View {
        let times = SolarTimes.sunriseSunset(on: date, latitude: latitude, longitude: longitude)
        HStack {
            HStack(spacing: 6) {
                VStack(spacing: 0) {
                    TechLabel(text: "Sunrise")
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ConsoleTheme.sun, ConsoleTheme.digit)
                }
                LCDDigits(value: times.sunrise.map(Self.hourMinute) ?? "--:--", size: 17)
            }
            Spacer()
            HStack(spacing: 6) {
                VStack(spacing: 0) {
                    TechLabel(text: "Sunset")
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ConsoleTheme.sun, ConsoleTheme.digit)
                }
                LCDDigits(value: times.sunset.map(Self.hourMinute) ?? "--:--", size: 17)
            }
        }
    }

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "H:mm"
        return f
    }()

    private static func hourMinute(_ date: Date) -> String { hmFormatter.string(from: date) }

    private static func seconds(_ date: Date) -> String {
        String(format: "%02d", Calendar.current.component(.second, from: date))
    }
}

// MARK: - BARO + RAIN

struct BaroRainTileView: View {
    @EnvironmentObject private var model: StationViewModel

    var body: some View {
        ScreenSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PillLabel(text: "Baro")
                    TechLabel(text: "Relative")
                }
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    LCDDigits(value: model.current?.pressureHpa.map { Format.number($0, digits: 0) } ?? "----",
                              size: 30, unit: "hPa")
                    TrendArrow(trend: model.pressureTrend)
                }
                Spacer(minLength: 0)
                HStack {
                    PillLabel(text: "Rain")
                    TechLabel(text: "Daily")
                }
                LCDDigits(value: Format.rain(model.current?.rainDayMm, imperial: false),
                          size: 26, color: ConsoleTheme.digitBlue, unit: "mm")
            }
        }
    }
}

// MARK: - Bande inférieure : graphe de pression + tous les canaux

struct HistoryStripView: View {
    @EnvironmentObject private var model: StationViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ScreenSection {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PillLabel(text: "History")
                        TechLabel(text: "Pression 24 h")
                    }
                    if model.pressureChart.count > 1 {
                        Chart(model.pressureChart) { point in
                            AreaMark(x: .value("Heure", point.date), y: .value("hPa", point.hpa))
                                .foregroundStyle(
                                    LinearGradient(colors: [ConsoleTheme.digitBlue.opacity(0.25), .clear],
                                                   startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Heure", point.date), y: .value("hPa", point.hpa))
                                .foregroundStyle(ConsoleTheme.digitBlue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .hour, count: 6)) {
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                                    .foregroundStyle(ConsoleTheme.label)
                            }
                        }
                        .chartYAxis {
                            AxisMarks {
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                                AxisValueLabel().foregroundStyle(ConsoleTheme.label)
                            }
                        }
                        .frame(height: 96)
                    } else {
                        Text("Historique 24 h en construction…")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(ConsoleTheme.label)
                            .frame(height: 96)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            ScreenSection {
                VStack(alignment: .leading, spacing: 6) {
                    PillLabel(text: "Capteurs")
                    if let channels = model.current?.channels, !channels.isEmpty {
                        ForEach(channels) { channel in
                            HStack(spacing: 8) {
                                Text(channel.label)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(ConsoleTheme.label)
                                Spacer()
                                if let t = channel.temperatureC {
                                    LCDDigits(value: Format.temp(t, imperial: false), size: 14, unit: "°C")
                                }
                                if let h = channel.humidity {
                                    LCDDigits(value: Format.percent(h), size: 14,
                                              color: ConsoleTheme.digitBlue, unit: "%")
                                }
                                if let m = channel.moisturePercent {
                                    LCDDigits(value: Format.percent(m), size: 14,
                                              color: ConsoleTheme.digitTeal, unit: "% sol")
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    } else {
                        Spacer()
                        Text("Aucun capteur additionnel reçu")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(ConsoleTheme.label)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
            }
            .frame(width: 320)
        }
        .frame(height: 140)
    }
}
