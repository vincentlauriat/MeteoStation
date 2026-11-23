import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var model: StationViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("layoutOverride") private var overrideRaw = LayoutOverride.auto.rawValue
    @AppStorage("latitude") private var latitude = 48.8566
    @AppStorage("longitude") private var longitude = 2.3522
    @State private var relayText = ""
    let posture: HingePosture

    private var relayStatusText: String {
        switch model.relayStatus {
        case .stopped: return "Arrêté"
        case .connecting: return "Connexion…"
        case .connected: return "Connecté"
        case .unreachable(let message): return "Injoignable — \(message)"
        }
    }

    private var postureText: String {
        switch posture {
        case .none: return "Pas de charnière détectée"
        case .closed: return "Plié"
        case .partiallyOpen(let angle): return "Entrouvert (\(Int(angle.rounded()))°)"
        case .fullyOpen: return "Déplié"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://raspcorse:8650", text: $relayText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(apply)
                    LabeledContent("État", value: relayStatusText)
                } header: {
                    Text("Relais")
                } footer: {
                    Text("Le Pi qui reçoit la console (Relay/meteorelay.py, port 8650). À distance : via Tailscale (app Tailscale active). Sur place : son adresse LAN fonctionne aussi.")
                }

                Section {
                    Picker("Mise en page", selection: $overrideRaw) {
                        ForEach(LayoutOverride.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    LabeledContent("Charnière", value: postureText)
                } header: {
                    Text("iPhone Duo")
                } footer: {
                    Text("Automatique : plié → vue compacte, déplié → console, entrouvert en portrait → station de bureau (écran maintenu allumé).")
                }

                Section("Position (lever / coucher du soleil)") {
                    TextField("Latitude", value: $latitude, format: .number.precision(.fractionLength(0...6)))
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", value: $longitude, format: .number.precision(.fractionLength(0...6)))
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        apply()
                        dismiss()
                    }
                }
            }
            .onAppear { relayText = model.relayAddress }
            // Fermeture par glissement : ne pas perdre l'adresse saisie.
            .onDisappear(perform: apply)
        }
        .preferredColorScheme(.dark)
    }

    private func apply() {
        model.relayAddress = relayText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
