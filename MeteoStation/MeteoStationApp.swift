import SwiftUI
import Sparkle

@main
struct MeteoStationApp: App {
    @StateObject private var model = StationViewModel()

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ConsoleView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Rechercher des mises à jour…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
