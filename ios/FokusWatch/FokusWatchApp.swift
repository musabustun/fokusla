import FokusData
import FokusDesign
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus.watch", category: "composition")

/// Fokus saat uygulaması. Telefon olmadan da çalışır: veri saatteki SwiftData deposundadır ve iPhone ile
/// AYNI CloudKit container'ı (private database) eşitler; telefon yakınsa `WatchConnectivity` anlık durum taşır.
@main
struct FokusWatchApp: App {
    @State private var model: WatchModel

    init() {
        FokusFonts.registerAll()
        let container = Self.makeContainer()
        FokusSystem.register(container)
        #if DEBUG
        Self.seedStoreListingDemoIfRequested()
        #endif
        _model = State(initialValue: WatchModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .fokusTheme()
                // "Gece mesaisi": saat her zaman koyu (açık görünüm tercihi saatte yoktur).
                .preferredColorScheme(.dark)
        }
    }

    #if DEBUG
    /// Mağaza ekran görüntüsü için: `-FokusWatchDemoSession` verilirse 23 dakikadır süren açık bir odak
    /// oturumu başlatır (yalnızca DEBUG; simülatörün kendi deposuna yazar, üretimi etkilemez).
    private static func seedStoreListingDemoIfRequested(now: Date = .now) {
        guard ProcessInfo.processInfo.arguments.contains("-FokusWatchDemoSession") else { return }
        _ = try? FocusActions.start(subjectId: nil, now: now.addingTimeInterval(-23 * 60 - 14))
    }
    #endif

    /// CloudKit → yerel → bellek içi sırasıyla düşer; açılışta asla çökmez (iOS ile aynı kural).
    /// Depo App Group'ta durur ki komplikasyon uzantısı okuyabilsin.
    private static func makeContainer() -> ModelContainer {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "FokusICloudContainer") as? String
        let storeURL = FokusAppGroup.resolveStoreURL()
        let preferred = FokusStore.preferredMode(
            containerIdentifier: identifier,
            syncEnabled: SyncPreferences.isEnabled(),
            iCloudAvailable: FileManager.default.ubiquityIdentityToken != nil)
        if case .cloudKit = preferred {
            do {
                return try FokusStore.makeContainer(mode: preferred, storeURL: storeURL)
            } catch {
                logger.error("CloudKit deposu kurulamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            return try FokusStore.makeContainer(mode: .local, storeURL: storeURL)
        } catch {
            logger.error("Depo kurulamadı: \(error.localizedDescription, privacy: .public)")
        }
        do {
            return try FokusStore.makeInMemoryContainer()
        } catch {
            preconditionFailure("Bellek içi ModelContainer kurulamadı: \(error)")
        }
    }
}
