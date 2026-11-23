import SwiftUI

@main
struct MeteoStationiOSApp: App {
    @StateObject private var model = StationViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            DuoRootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.becameActive()
            case .background: model.movedToBackground()
            default: break
            }
        }
    }
}
