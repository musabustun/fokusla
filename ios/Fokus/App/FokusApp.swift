import FokusData
import FokusDesign
import SwiftData
import SwiftUI

@main
struct FokusApp: App {
    private let environment: AppEnvironment

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
        }
        .modelContainer(environment.container)
    }
}
