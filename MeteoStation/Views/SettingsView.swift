import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: StationViewModel
    @AppStorage("useImperial") private var imperial = false
    @AppStorage("latitude") private var latitude = 48.8566
    @AppStorage("longitude") private var longitude = 2.3522
    @State private var portText = ""

    var body: some View {
        Form {
            Section("Serveur local") {
                LabeledContent("Adresse du Mac", value: model.localIP)
                HStack {
                    TextField("Port d'écoute", text: $portText)
                        .frame(width: 100)
                        .onSubmit(applyPort)
                    Button("Appliquer", action: applyPort)
                }
                Text("À renseigner dans l'app WSLink (service météo personnalisé, protocole Wunderground) :\nserveur \(model.localIP) · port \(String(model.port)) · chemin /weatherstation/updateweatherstation.php")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
        .frame(width: 520, height: 420)
        .onAppear { portText = String(model.port) }
    }

    private func applyPort() {
        guard let port = Int(portText), (1...65535).contains(port) else {
            portText = String(model.port)
            return
        }
        model.port = port
    }
}
