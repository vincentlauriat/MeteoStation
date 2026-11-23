import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: StationViewModel
    @AppStorage("useImperial") private var imperial = false
    @AppStorage("latitude") private var latitude = 48.8566
    @AppStorage("longitude") private var longitude = 2.3522
    @State private var portText = ""
    @State private var relayText = ""

    private var relayStatusText: String {
        switch model.relayStatus {
        case .stopped: return "Arrêté"
        case .connecting: return "Connexion…"
        case .connected: return "Connecté"
        case .unreachable(let message): return "Injoignable — \(message)"
        }
    }

    var body: some View {
        Form {
            Section("Source des données") {
                Picker("Source", selection: $model.dataSource) {
                    Text("Station sur le réseau local").tag(DataSource.local)
                    Text("Relais distant (Raspberry Pi via Tailscale)").tag(DataSource.relay)
                }
                .pickerStyle(.inline)
                if model.dataSource == .relay {
                    HStack {
                        TextField("Adresse du relais", text: $relayText, prompt: Text("http://raspcorse:8650"))
                            .onSubmit { model.relayAddress = relayText }
                        Button("Appliquer") { model.relayAddress = relayText }
                    }
                    LabeledContent("État", value: relayStatusText)
                    Text("La console pousse vers le relais (Relay/meteorelay.py), qui garde 7 jours de mesures. L'app les lit toutes les 5 s et rattrape l'historique au réveil du Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if model.dataSource == .local {
            Section("Serveur local") {
                LabeledContent("Adresse du Mac", value: model.localIP)
                HStack {
                    TextField("Port d'écoute", text: $portText)
                        .frame(width: 100)
                        .onSubmit(applyPort)
                    Button("Appliquer", action: applyPort)
                }
                Text("À renseigner dans la console en mode AP ([SENSOR/WI-FI] 6 s → WiFi PWS-XXXXXX → http://192.168.1.1), service météo à URL libre :\nURL \(model.localIP):\(String(model.port)) — ID/clé libres (protocole Wunderground)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            }

            Section("Affichage") {
                Picker("Unités", selection: $imperial) {
                    Text("Métriques (°C, km/h, mm, hPa)").tag(false)
                    Text("Impériales (°F, mph, in, inHg)").tag(true)
                }
                .pickerStyle(.inline)
            }

            Section("Position (lever / coucher du soleil)") {
                TextField("Latitude", value: $latitude, format: .number.precision(.fractionLength(0...6)))
                TextField("Longitude", value: $longitude, format: .number.precision(.fractionLength(0...6)))
                Text("Par défaut : Paris. Utilisée uniquement pour le calcul local des éphémérides.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Débogage") {
                if model.lastRawRequest.isEmpty {
                    Text("Aucune requête reçue pour l'instant.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        Text(model.lastRawRequest)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 480)
        .onAppear {
            portText = String(model.port)
            relayText = model.relayAddress
        }
    }

    private func applyPort() {
        guard let port = Int(portText), (1...65535).contains(port) else {
            portText = String(model.port)
            return
        }
        model.port = port
    }
}
