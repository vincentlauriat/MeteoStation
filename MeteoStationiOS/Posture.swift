import SwiftUI
import UIKit

/// Posture physique de l'appareil, d'après la charnière (iPhone Duo, iOS 27.1+).
enum HingePosture: Equatable {
    /// Pas de charnière (iPhone classique) ou état inconnu.
    case none
    case closed
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
    /// Charnière entrouverte + écran en portrait (pli horizontal) → station de bureau ;
    /// écran large (intérieur déplié, iPad) → console ; sinon vue compacte.
    static func resolve(posture: HingePosture, size: CGSize, override: LayoutOverride) -> DuoLayout {
        switch override {
        case .compact: return .compact
        case .console: return .console
        case .desk: return .desk
        case .auto: break
        }
        if case .partiallyOpen = posture, size.height > size.width, size.width >= 560 {
            return .desk
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
            let interaction = UIHingeInteraction { _, update in
                let posture = Self.posture(from: update.hinge)
                DispatchQueue.main.async { self.posture = posture }
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
        case .partiallyOpen: return .partiallyOpen(angle: Double(hinge.angle))
        case .fullyOpen: return .fullyOpen
        default: return .none
        }
    }
}
