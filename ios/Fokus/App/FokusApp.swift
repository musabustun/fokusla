import FokusData
import FokusDesign
import SwiftData
import SwiftUI

@main
struct FokusApp: App {
    private let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FokusFonts.registerAll()
        environment = AppEnvironment.make()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .fokusTheme()
                .background(.fkBackground)
                .environment(\.authService, environment.authService)
                .environment(\.syncService, environment.syncService)
                .environment(\.notificationService, environment.notificationService)
                .environment(\.focusSound, environment.focusSound)
                .environment(\.musicRegistry, environment.musicRegistry)
                .onOpenURL { environment.musicRegistry.handleOpenURL($0) }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: environment.musicRegistry.sceneDidBecomeActive()
                    case .inactive, .background: environment.musicRegistry.sceneWillResignActive()
                    @unknown default: break
                    }
                }
        }
        .modelContainer(environment.container)
    }
}
