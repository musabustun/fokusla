import FokusData
import FokusDesign
import SwiftData
import SwiftUI

@main
struct FokusApp: App {
    private let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    /// iPhone yön kilidi (tam ekran odakta yatay serbest): bkz. `ImmersiveOrientation`.
    @UIApplicationDelegateAdaptor(FokusAppDelegate.self) private var appDelegate

    init() {
        FokusFonts.registerAll()
        environment = AppEnvironment.make()
        ImmersiveUITestSupport.resetStoredPageIfNeeded()
        // Apple Watch ile anlık odak durumu (WatchConnectivity); kalıcı veri yine CloudKit'ten akar.
        FocusLinkCoordinator.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                // Tema/ortam değiştiricilerinin İÇİNDE: kapak onların ortamını (palet, ses, model) devralır.
                .immersiveFocusHost()
                .fokusSystemIntegration()
                .fokusTheme()
                .background(.fkBackground)
                .environment(\.authService, environment.authService)
                .environment(\.syncService, environment.syncService)
                .environment(\.socialService, environment.socialService)
                .environment(\.notificationService, environment.notificationService)
                .environment(\.focusSound, environment.focusSound)
                .environment(\.musicRegistry, environment.musicRegistry)
                .onOpenURL { environment.musicRegistry.handleOpenURL($0) }
                // `initial: true`: soğuk açılışta da (faz değişimi olmadan) Spotify kayıtlı token ile sessizce bağlansın.
                .onChange(of: scenePhase, initial: true) { _, phase in
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
