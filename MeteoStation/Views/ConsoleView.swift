import SwiftUI

/// Écran principal : reproduction de la console Bresser Weather Center 7-in-1 —
/// écran LCD en grille 3×3 dans un boîtier noir, boutons physiques à droite.
struct ConsoleView: View {
    @EnvironmentObject private var model: StationViewModel
    @AppStorage("showHistory") private var showHistory = true

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("METEOSTATION")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Color.white.opacity(0.35))

                if model.current == nil {
                    WaitingBanner()
                }

                // La grille de la console : OUT/WIND/IN, INDEX/SUN/FORECAST, DATE/TIME/BARO+RAIN.
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        OutTileView()
                        ScreenSection {
                            VStack(alignment: .leading, spacing: 4) {
                                PillLabel(text: "Wind")
                                WindCompassView(reading: model.current)
                            }
                        }
                        InTileView()
                    }
                    .frame(height: 290)
                    GridRow {
                        IndexTileView(reading: model.current)
                        SunTileView(reading: model.current)
                        ForecastTileView(forecast: model.forecast)
                    }
                    .frame(height: 108)
                    GridRow {
                        DateTileView()
                        TimeTileView()
                        BaroRainTileView()
                    }
                    .frame(height: 138)
                }

                if showHistory {
                    HistoryStripView()
                }

                StatusBarView()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ConsoleTheme.screen)
            )
            .padding([.vertical, .leading], 14)

            BezelButtonsView(showHistory: $showHistory)
                .padding(.trailing, 6)
        }
        .frame(minWidth: 1040, minHeight: showHistory ? 780 : 640)
        .background(ConsoleTheme.bezel)
        .onAppear { _ = model }
    }
}

// MARK: - Boutons du boîtier (HISTORY, MAX/MIN, CHANNEL)

struct BezelButtonsView: View {
    @EnvironmentObject private var model: StationViewModel
    @Binding var showHistory: Bool
    @State private var showMaxMin = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            bezelButton("HISTORY") { showHistory.toggle() }
            bezelButton("MAX\nMIN") { showMaxMin.toggle() }
                .popover(isPresented: $showMaxMin, arrowEdge: .leading) {
                    MaxMinPopover(stats: model.todayStats)
                }
            bezelButton("CHANNEL") { model.cycleChannel() }
            Spacer()
        }
        .frame(width: 74)
    }

    private func bezelButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 58, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Popover MAX/MIN du jour

struct MaxMinPopover: View {
    let stats: StationViewModel.TodayStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aujourd'hui")
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                row("Température", stats.tempMin, stats.tempMax, "°C")
                row("Humidité", stats.humidityMin, stats.humidityMax, "%", digits: 0)
                row("Pression", stats.pressureMin, stats.pressureMax, "hPa", digits: 0)
                GridRow {
                    Text("Rafale max").foregroundStyle(.secondary)
                    Text(stats.gustMax.map { Format.number($0) + " km/h" } ?? "--")
                        .gridCellColumns(2)
                }
            }
            .font(.system(size: 11, design: .rounded))
        }
        .padding(12)
    }

    private func row(_ label: String, _ min: Double?, _ max: Double?, _ unit: String, digits: Int = 1) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(min.map { Format.number($0, digits: digits) + " " + unit } ?? "--")
            Text(max.map { Format.number($0, digits: digits) + " " + unit } ?? "--")
        }
    }
}

// MARK: - Bannière d'attente et de configuration

struct WaitingBanner: View {
    @EnvironmentObject private var model: StationViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 20))
                .foregroundStyle(ConsoleTheme.digitBlue)
            VStack(alignment: .leading, spacing: 3) {
                Text("En attente de données de la station…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Dans WSLink → service personnalisé : serveur \(model.localIP), port \(String(model.port)), chemin /weatherstation/updateweatherstation.php (protocole Wunderground).")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(ConsoleTheme.label)
                    .textSelection(.enabled)
            }
            Spacer()
            Toggle("Mode démo", isOn: $model.demoMode)
                .toggleStyle(.switch)
                .controlSize(.small)
                .foregroundStyle(ConsoleTheme.label)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ConsoleTheme.digitBlue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(ConsoleTheme.digitBlue.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Barre de statut

struct StatusBarView: View {
    @EnvironmentObject private var model: StationViewModel

    private var statusColor: Color {
        switch model.status {
        case .listening: return .green
        case .starting: return .orange
        case .failed: return .red
        case .stopped: return .gray
        }
    }

    private var statusText: String {
        switch model.status {
        case .listening(let port): return "En écoute sur \(model.localIP):\(port)"
        case .starting: return "Démarrage du serveur…"
        case .failed(let message): return "Erreur : \(message)"
        case .stopped: return "Serveur arrêté"
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ConsoleTheme.label)
                    .textSelection(.enabled)
                Spacer()
                if model.current?.lowBattery == true {
                    Label("Pile station faible", systemImage: "battery.25")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsoleTheme.alert)
                }
                Text("Dernière réception : \(Format.relativeAge(since: model.lastReceived))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ConsoleTheme.label)
            }
        }
        .padding(.horizontal, 4)
    }
}
