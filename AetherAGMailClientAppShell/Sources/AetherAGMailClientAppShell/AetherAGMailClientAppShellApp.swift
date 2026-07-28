import SwiftUI
import AetherAGMailClientApp

@main
struct AetherAGMailClientAppShellApp: App {
    @StateObject private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appContainer)
        }
    }
}
