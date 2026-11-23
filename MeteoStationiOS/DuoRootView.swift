import SwiftUI
import UIKit

/// Racine iOS : choisit la mise en page selon la posture de l'iPhone Duo
/// (charnière) et la taille de l'écran actif (écran extérieur plié, intérieur déplié).
struct DuoRootView: View {
    @EnvironmentObject private var model: StationViewModel
    @AppStorage("layoutOverride") private var overrideRaw = LayoutOverride.auto.rawValue
    @State private var posture: HingePosture = .none
    @State private var showSettings = false
    @State private var layout: DuoLayout = .compact

    var body: some View {
        GeometryReader { geo in
            let resolved = DuoLayout.resolve(
                posture: posture,
                size: geo.size,
                override: LayoutOverride(rawValue: overrideRaw) ?? .auto,
                current: layout
            )
            ZStack(alignment: .topTrailing) {
                ConsoleTheme.bezel.ignoresSafeArea()

                switch resolved {
                case .compact: CompactPhoneView()
                case .console: ScaledConsoleView()
                case .desk: DeskStationView()
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(10)
                }
                .accessibilityLabel("Réglages")
            }
            .onChange(of: resolved, initial: true) { _, newLayout in
                layout = newLayout  // mémorisé pour l'hystérésis de la station de bureau
                // Station de bureau : l'écran reste allumé, comme une vraie console.
                UIApplication.shared.isIdleTimerDisabled = newLayout == .desk
            }
            .animation(.easeInOut(duration: 0.25), value: resolved)
        }
        .background(HingeReader(posture: $posture))
        .sheet(isPresented: $showSettings) {
            IOSSettingsView(posture: posture)
                .environmentObject(model)
        }
        .onAppear {
            if model.relayAddress.isEmpty { showSettings = true }
        }
    }
}

// MARK: - Déplié : la console complète, mise à l'échelle

/// La console macOS (grille 3×3 + boutons du boîtier) rendue à sa taille de
/// conception puis réduite pour tenir dans l'écran intérieur, sans recomposer la mise en page.
struct ScaledConsoleView: View {
    @AppStorage("showHistory") private var showHistory = true

    var body: some View {
        GeometryReader { geo in
            let design = CGSize(width: 1040, height: showHistory ? 780 : 640)
            let scale = min(geo.size.width / design.width, geo.size.height / design.height)
            ConsoleView()
                .frame(width: design.width, height: design.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Plié : vue compacte (écran extérieur)

struct CompactPhoneView: View {
    @EnvironmentObject private var model: StationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("METEOSTATION")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)

                if model.current == nil {
                    WaitingBanner()
                }

                TimeTileView().frame(height: 128)
                OutTileView().frame(height: 160)
                ScreenSection {
                    VStack(alignment: .leading, spacing: 4) {
                        PillLabel(text: "Wind")
                        WindCompassView(reading: model.current)
                    }
                }
                .frame(height: 280)
                HStack(spacing: 10) {
                    ForecastTileView(forecast: model.forecast)
                    BaroRainTileView()
                }
                .frame(height: 150)
                ScreenSection {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            PillLabel(text: "History")
                            TechLabel(text: "Pression 24 h")
                        }
                        PressureChartView(height: 110)
                    }
                }
                IndexTileView(reading: model.current).frame(height: 108)
                SunTileView(reading: model.current).frame(height: 108)
                InTileView().frame(height: 190)
                StatusBarView()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(ConsoleTheme.screen.ignoresSafeArea())
    }
}

// MARK: - Entrouvert : station de bureau

/// iPhone Duo posé entrouvert, pli horizontal : la moitié haute (verticale)
/// se lit de loin — heure, température, prévision ; la moitié basse (à plat)
/// porte le graphe de pression, le vent, la pression et la pluie.
/// Rien n'est dessiné sur la ligne de pli.
struct DeskStationView: View {
    @EnvironmentObject private var model: StationViewModel
    private let foldGap: CGFloat = 28
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            // Le pli est au milieu physique de l'écran : on partage la hauteur totale,
            // puis chaque moitié respecte sa propre zone sûre.
            let half = (geo.size.height + insets.top + insets.bottom - foldGap) / 2
            let width = geo.size.width
            VStack(spacing: foldGap) {
                topHalf(width: width, height: half - insets.top)
                    .padding(.top, insets.top)
                    .frame(height: half)
                bottomHalf(width: width, height: half - insets.bottom)
                    .padding(.bottom, insets.bottom)
                    .frame(height: half)
            }
            .padding(.horizontal, 12)
            .frame(width: geo.size.width)
            .offset(y: -insets.top)
        }
        .background(ConsoleTheme.screen.ignoresSafeArea())
    }

    private func topHalf(width: CGFloat, height: CGFloat) -> some View {
        let clockSize = min(110, width * 0.15, height * 0.24)
        return VStack(spacing: spacing) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    LCDDigits(value: Self.hourMinute(context.date), size: clockSize)
                    LCDDigits(value: String(format: "%02d", Calendar.current.component(.second, from: context.date)),
                              size: clockSize * 0.36)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: clockSize * 1.25)
            HStack(spacing: spacing) {
                OutTileView(scale: min(2, max(1, width / 420)))
                ForecastTileView(forecast: model.forecast)
                    .frame(width: width * 0.3)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func bottomHalf(width: CGFloat, height: CGFloat) -> some View {
        let statusHeight: CGFloat = 20
        let usable = height - statusHeight - 2 * spacing
        return VStack(spacing: spacing) {
            ScreenSection {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PillLabel(text: "History")
                        TechLabel(text: "Pression 24 h")
                    }
                    PressureChartView(height: max(60, usable * 0.38 - 50))
                }
            }
            .frame(height: usable * 0.38)
            HStack(spacing: spacing) {
                ScreenSection {
                    VStack(alignment: .leading, spacing: 4) {
                        PillLabel(text: "Wind")
                        WindCompassView(reading: model.current)
                    }
                }
                BaroRainTileView()
                    .frame(width: width * 0.32)
            }
            .frame(height: usable * 0.62)
            StatusBarView()
                .frame(height: statusHeight)
        }
    }

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "H:mm"
        return f
    }()

    private static func hourMinute(_ date: Date) -> String { hmFormatter.string(from: date) }
}
