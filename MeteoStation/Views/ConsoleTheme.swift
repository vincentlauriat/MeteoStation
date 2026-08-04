import SwiftUI

/// Palette et briques visuelles calquées sur l'écran LCD de la console
/// Bresser 7-in-1 : fond noir, pastilles bleues, chiffres 7 segments.
enum ConsoleTheme {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let screen = Color(red: 0.035, green: 0.045, blue: 0.075)
    static let bezel = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let tileBorder = Color.white.opacity(0.06)
    static let label = Color.white.opacity(0.55)

    /// Bleu des pastilles de section (OUT, WIND, IN…).
    static let pill = Color(red: 0.16, green: 0.42, blue: 0.95)

    /// Chiffres LCD : blanc bleuté principal, bleu saturé (humidité, pluie),
    /// turquoise (ressenti), violet (arc de vent).
    static let digit = Color(red: 0.78, green: 0.90, blue: 1.0)
    static let digitBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let digitTeal = Color(red: 0.42, green: 0.90, blue: 0.85)
    static let windArc = Color(red: 0.78, green: 0.55, blue: 0.95)

    static let sun = Color(red: 1.0, green: 0.72, blue: 0.15)
    static let cloud = Color(red: 0.45, green: 0.68, blue: 1.0)
    static let alert = Color(red: 1.0, green: 0.35, blue: 0.30)
}

/// Pastille de section bleue (OUT, WIND, IN, FORECAST…).
struct PillLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(ConsoleTheme.pill))
    }
}

/// Petit libellé technique gris (FEELS LIKE, AVERAGE, RELATIVE, DAILY…).
struct TechLabel: View {
    let text: String
    var size: CGFloat = 9

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(1)
            .foregroundStyle(ConsoleTheme.label)
    }
}

/// Chiffres 7 segments (police DSEG) avec segments fantômes en arrière-plan,
/// comme sur un vrai LCD.
struct LCDDigits: View {
    let value: String
    var size: CGFloat = 34
    var color: Color = ConsoleTheme.digit
    var unit: String? = nil
    var unitColor: Color? = nil

    private var ghost: String {
        String(value.map { c in
            if c.isNumber || c == "-" || c.isLetter { return "8" }
            return c
        })
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            ZStack(alignment: .trailing) {
                Text(ghost)
                    .foregroundStyle(color.opacity(0.09))
                Text(value)
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.45), radius: 5)
            }
            .font(.custom("DSEG7Classic-BoldItalic", size: size))
            if let unit {
                Text(unit)
                    .font(.system(size: max(10, size * 0.3), weight: .bold, design: .rounded))
                    .foregroundStyle((unitColor ?? color).opacity(0.85))
            }
        }
        .lineLimit(1)
    }
}

/// Texte alphanumérique 14 segments (jours, points cardinaux…).
struct LCDText: View {
    let value: String
    var size: CGFloat = 18
    var color: Color = ConsoleTheme.digit

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(String(repeating: "~", count: value.count))
                .foregroundStyle(color.opacity(0.09))
            Text(value)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.45), radius: 5)
        }
        .font(.custom("DSEG14Classic-BoldItalic", size: size))
        .lineLimit(1)
    }
}

/// Zone de l'écran LCD : léger cadre, fond très sombre.
struct ScreenSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.015))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(ConsoleTheme.tileBorder, lineWidth: 1)
                    )
            )
    }
}

/// Ligne libellé/valeur pour la bande inférieure (canaux, réglages).
struct DataRow: View {
    let label: String
    let value: String
    let unit: String
    var color: Color = ConsoleTheme.digit

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ConsoleTheme.label)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(color.opacity(0.6))
        }
    }
}
