import AetherAGMailClientApp
import SwiftUI

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
