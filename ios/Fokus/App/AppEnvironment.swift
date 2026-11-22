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

        do {
            try CurriculumSeeder.ensureSeeded(context: container.mainContext)
        } catch {
            logger.error("Müfredat tohumlanamadı: \(error.localizedDescription, privacy: .public)")
        }

        return AppEnvironment(
            container: container,
            authService: AppleAuthService(),
            syncService: CloudKitSyncService(isActive: usedCloudKit, defaults: defaults),
            // UI testleri sistem izin iletişim kutusunu görmesin diye sahte servis (izin verir).
            notificationService: isUITest ? MockNotificationService() : SystemNotificationService(),
            focusSound: FocusSoundPlayer(),
            musicRegistry: MusicProviderRegistry(providers: FocusMusicProviders.make())
        )
    }

    private static func buildContainer() -> (ModelContainer, Bool) {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "FokusICloudContainer") as? String
        let preferred = FokusStore.preferredMode(
            containerIdentifier: identifier,
            syncEnabled: SyncPreferences.isEnabled(),
            iCloudAvailable: FileManager.default.ubiquityIdentityToken != nil
        )
        if case .cloudKit = preferred {
            do {
                return (try FokusStore.makeContainer(mode: preferred), true)
            } catch {
                logger.error("CloudKit deposu kurulamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
        return (makeContainerOrFallback(for: .local), false)
    }

    /// İstenen modu dener; olmazsa bellek içine düşer.
    private static func makeContainerOrFallback(for mode: FokusStore.Mode) -> ModelContainer {
        do {
            return try FokusStore.makeContainer(mode: mode)
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
}
