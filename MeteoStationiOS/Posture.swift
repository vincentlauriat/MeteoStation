import SwiftUI
import UIKit

/// Posture physique de l'appareil, d'après la charnière (iPhone Duo, iOS 27.1+).
enum HingePosture: Equatable {
    /// Pas de charnière (iPhone classique) ou état inconnu.
    case none
    case closed
    /// Angle d'ouverture en degrés (UIHinge le fournit en radians).
    case partiallyOpen(angle: Double)
    case fullyOpen
}

/// Mise en page choisie par l'utilisateur (auto, ou forcée : utile au simulateur).
enum LayoutOverride: String, CaseIterable, Identifiable {
    case auto, compact, console, desk
    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Automatique (charnière)"
        case .compact: return "Plié : vue compacte"
        case .console: return "Déplié : console"
        case .desk: return "Entrouvert : station de bureau"
        }
    }
}

enum DuoLayout: Equatable {
    case compact, console, desk
}

extension DuoLayout {
    /// Plage d'angle de la station de bureau, avec hystérésis : on y entre entre
    /// 60° et 150°, on n'en sort qu'en dehors de 50°–160°, pour éviter le
    /// clignotement pendant qu'on ouvre ou ferme l'appareil.
    static let deskEnter: ClosedRange<Double> = 60...150
    static let deskStay: ClosedRange<Double> = 50...160

    /// Charnière entrouverte dans la plage « bureau » + écran en portrait (pli
    /// horizontal) → station de bureau ; écran large (intérieur déplié, iPad) →
    /// console ; sinon vue compacte.
    static func resolve(posture: HingePosture, size: CGSize, override: LayoutOverride,
                        current: DuoLayout? = nil) -> DuoLayout {
        switch override {
        case .compact: return .compact
        case .console: return .console
        case .desk: return .desk
        case .auto: break
        }
        if case .partiallyOpen(let angle) = posture, size.height > size.width, size.width >= 560 {
            let band = current == .desk ? deskStay : deskEnter
            if band.contains(angle) { return .desk }
        }
        return size.width >= 560 ? .console : .compact
    }
}

/// Pont UIKit → SwiftUI pour `UIHingeInteraction` (aucun équivalent SwiftUI).
/// Vue transparente, sans interaction, posée en arrière-plan de la racine.
struct HingeReader: UIViewRepresentable {
    @Binding var posture: HingePosture

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        if #available(iOS 27.1, *) {
            // Le gestionnaire est appelé sur le main actor, état initial compris.
            let interaction = UIHingeInteraction { _, update in
                self.posture = Self.posture(from: update.hinge)
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @available(iOS 27.1, *)
    private static func posture(from hinge: UIHinge?) -> HingePosture {
        guard let hinge else { return .none }
        switch hinge.status {
        case .closed: return .closed
        case .partiallyOpen: return .partiallyOpen(angle: Double(hinge.angle) * 180 / .pi)
        case .fullyOpen: return .fullyOpen
        default: return .none
        }
    }
}
