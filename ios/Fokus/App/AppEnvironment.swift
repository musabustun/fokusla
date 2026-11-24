import FokusAudio
import FokusData
import FokusDesign
import Foundation
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "composition")

/// Uygulama açılışında kurulan servisler ve veri deposu (kompozisyon kökü).
@MainActor
struct AppEnvironment {
    /// UI testleri için: bellek içi depo ve sıfırlanmış tema tercihleri.
    static let uiTestLaunchArgument = "-FokusUITestMode"

    let container: ModelContainer
    let authService: any AuthService
    let syncService: any SyncService
    let notificationService: any NotificationService
    /// Cihazda üretilen odak sesleri ve harici müzik sağlayıcıları (Odak tam ekranı kullanır).
    let focusSound: FocusSoundPlayer
    let musicRegistry: MusicProviderRegistry
    let socialService: any SocialService

    /// Container'ı kurar: CloudKit → yerel → bellek içi sırasıyla düşer; açılışta asla çökmez.
    static func make(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) -> AppEnvironment {
        let isUITest = arguments.contains(uiTestLaunchArgument)
        if isUITest {
            defaults.removeObject(forKey: FokusThemeKeys.appearance)
            defaults.removeObject(forKey: FokusThemeKeys.palette)
            defaults.removeObject(forKey: SyncPreferences.enabledKey)
            ReminderPreferences(defaults: defaults).reset()
        }

        let (container, usedCloudKit) = isUITest
            ? (makeContainerOrFallback(for: .inMemory), false)
            : buildContainer()

        FokusSystem.register(container)
        #if DEBUG
        DebugDemoData.seedIfRequested(container: container)
        if !isUITest { DebugCloudKitSchemaInit.runIfRequested() }
        #endif

        do {
            try CurriculumSeeder.ensureSeeded(context: container.mainContext)
        } catch {
            logger.error("Müfredat tohumlanamadı: \(error.localizedDescription, privacy: .public)")
        }
        #if DEBUG
        StoreListingDemoData.seedIfRequested(container: container)
        #endif

        return AppEnvironment(
            container: container,
            authService: AppleAuthService(),
            syncService: CloudKitSyncService(isActive: usedCloudKit, defaults: defaults),
            // UI testleri sistem izin iletişim kutusunu görmesin diye sahte servis (izin verir).
            notificationService: isUITest ? MockNotificationService() : SystemNotificationService(),
            focusSound: FocusSoundPlayer(),
            musicRegistry: MusicProviderRegistry(providers: FocusMusicProviders.make()),
            socialService: makeSocialService(container: container, isUITest: isUITest, arguments: arguments, defaults: defaults)
        )
    }

    /// Sosyal: gerçek servis + CloudKit (docs/social-cloudkit.md). Oturum, profildeki Apple kimliğinden gelir.
    /// UI testlerinde aynı servis bellek içi sahte sunucuyla, örnek kişilerle çalışır (ağ yok).
    private static func makeSocialService(
        container: ModelContainer, isUITest: Bool, arguments: [String], defaults: UserDefaults
    ) -> any SocialService {
        let sessionProvider: @MainActor () async -> String? = {
            (try? ProfileRepository(context: container.mainContext).current())?.appleUserId
        }
        #if DEBUG
        if isUITest {
            let isSignedIn = arguments.contains(socialSignedInLaunchArgument)
            let world = SocialDemoWorld(sessionProvider: {
                if isSignedIn { return "ui-test" }
                return await sessionProvider()
            })
            world.start()
            socialDemoWorld = world
            return world.service
        }
        #endif
        let identifier = Bundle.main.object(forInfoDictionaryKey: "FokusICloudContainer") as? String
        return CloudSocialService(
            sessionProvider: sessionProvider,
            cloud: CloudKitSocialCloud(containerIdentifier: identifier ?? ""), defaults: defaults)
    }

    #if DEBUG
    /// UI testleri gerçek Apple girişi yapamaz: bu argümanla Sosyal oturumu açık sayılır.
    static let socialSignedInLaunchArgument = "-FokusUITestSocialSignedIn"
    private static var socialDemoWorld: SocialDemoWorld?
    #endif

    private static func buildContainer() -> (ModelContainer, Bool) {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "FokusICloudContainer") as? String
        // App Group varsa depo orada durur (widget/intent'ler paylaşır); eski konumdaki veri taşınır.
        // Yoksa (imzasız simülatör derlemesi) varsayılan konum: davranış eskisi gibi.
        let storeURL = FokusAppGroup.resolveStoreURL()
        let preferred = FokusStore.preferredMode(
            containerIdentifier: identifier,
            syncEnabled: SyncPreferences.isEnabled(),
            iCloudAvailable: FileManager.default.ubiquityIdentityToken != nil
        )
        if case .cloudKit = preferred {
            do {
                return (try FokusStore.makeContainer(mode: preferred, storeURL: storeURL), true)
            } catch {
                logger.error("CloudKit deposu kurulamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
        return (makeContainerOrFallback(for: .local, storeURL: storeURL), false)
    }

    /// İstenen modu dener; olmazsa bellek içine düşer.
    private static func makeContainerOrFallback(
        for mode: FokusStore.Mode, storeURL: URL? = nil
    ) -> ModelContainer {
        do {
            return try FokusStore.makeContainer(mode: mode, storeURL: storeURL)
        } catch {
            logger.error("Depo kurulamadı: \(error.localizedDescription, privacy: .public)")
        }
        do {
            return try FokusStore.makeInMemoryContainer()
        } catch {
            // Bellek içi kurulum yalnızca şema hatasıyla başarısız olur; bu bir geliştirici hatasıdır.
            preconditionFailure("Bellek içi ModelContainer kurulamadı: \(error)")
        }
    }
}

extension EnvironmentValues {
    /// Servisler kökte (`FokusApp`) sağlanır; önizlemelerde `nil` olabilir.
    @Entry var authService: (any AuthService)? = nil
    @Entry var syncService: (any SyncService)? = nil
    @Entry var notificationService: (any NotificationService)? = nil
    @Entry var focusSound: (any FocusSoundControlling)? = nil
    @Entry var musicRegistry: MusicProviderRegistry? = nil
    @Entry var socialService: (any SocialService)? = nil
}
