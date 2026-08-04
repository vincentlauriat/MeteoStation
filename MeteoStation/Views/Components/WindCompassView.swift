import SwiftUI

/// Boussole de vent fidèle à la console : rose graduée avec lettres internes,
/// arc violet marquant la direction, direction 14 segments et vitesse moyenne
/// au centre, échelle de Beaufort en dessous.
struct WindCompassView: View {
    let reading: WeatherReading?

    private let diameter: CGFloat = 195

    private var beaufort: Int {
        guard let kmh = reading?.windSpeedKmh else { return 0 }
        let bounds: [Double] = [1, 5, 11, 19, 28, 38, 49, 61, 74, 88, 102, 117]
        return bounds.firstIndex(where: { kmh < $0 }) ?? 12
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)

                ForEach(0..<72, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(i % 18 == 0 ? 0.5 : 0.22))
                        .frame(width: 1.5, height: i % 18 == 0 ? 9 : 5)
                        .offset(y: -diameter / 2 + 9)
                        .rotationEffect(.degrees(Double(i) * 5))
                }

                // Arc violet de direction (± 25° autour de la direction du vent).
                if let dir = reading?.windDirDegrees {
                    Circle()
                        .trim(from: 0, to: 50 / 360)
                        .stroke(ConsoleTheme.windArc,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [3, 4]))
                        .frame(width: diameter - 26, height: diameter - 26)
                        .rotationEffect(.degrees(dir - 90 - 25))
                        .shadow(color: ConsoleTheme.windArc.opacity(0.6), radius: 5)
                        .animation(.easeInOut(duration: 0.8), value: dir)
                }

                cardinal("N", angle: 0)
                cardinal("E", angle: 90)
                cardinal("S", angle: 180)
                cardinal("W", angle: 270)

                VStack(spacing: 3) {
                    LCDText(value: Format.windDirectionEN(reading?.windDirDegrees),
                            size: 20, color: ConsoleTheme.digit)
                    TechLabel(text: "Average")
                    LCDDigits(value: Format.windMs(reading?.windSpeedKmh),
                              size: 30, color: ConsoleTheme.digit,
                              unit: "m/s", unitColor: ConsoleTheme.digitBlue)
                }
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity)

            // Échelle de Beaufort (0–12), comme la réglette sous la rose.
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(0..<13, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(i <= beaufort && reading?.windSpeedKmh != nil
                                  ? beaufortColor(i)
                                  : Color.white.opacity(0.10))
                            .frame(height: 6)
                    }
                }
                HStack {
                    TechLabel(text: "Beaufort \(beaufort)")
                    Spacer()
                    TechLabel(text: "Rafale")
                    LCDDigits(value: Format.speed(reading?.windGustKmh, imperial: false),
                              size: 13, color: ConsoleTheme.digit, unit: "km/h")
                }
            }
        }
    }

    private func beaufortColor(_ index: Int) -> Color {
        switch index {
        case 0...3: return ConsoleTheme.digitTeal
        case 4...6: return ConsoleTheme.sun
        case 7...9: return .orange
        default: return ConsoleTheme.alert
        }
    }

    private func cardinal(_ letter: String, angle: Double) -> some View {
        Text(letter)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(letter == "N" ? ConsoleTheme.digit : Color.white.opacity(0.55))
            .rotationEffect(.degrees(-angle))
            .offset(y: -diameter / 2 + 24)
            .rotationEffect(.degrees(angle))
    }
}
