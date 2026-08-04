import SwiftUI

@main
struct MeteoStationApp: App {
    @StateObject private var model = StationViewModel()

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

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
