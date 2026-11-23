import FokusData
import FokusDesign
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus.watch", category: "composition")

/// Fokus saat uygulaması. Telefon olmadan da çalışır: veri saatteki SwiftData deposundadır. Odak kayıtları
/// iPhone ile `WatchConnectivity` üzerinden kayıt kayıt eşlenir (`FocusLinkCoordinator`); telefon kayıtları
/// kendi deposuna yazınca CloudKit onları iPad'e taşır. Saat deposu CloudKit'e BAĞLANMAZ (bkz. `makeContainer`).
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
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-FokusWatchDemoSession") else { return }
        _ = try? FocusActions.start(subjectId: nil, now: now.addingTimeInterval(-23 * 60 - 14))
        // `-FokusWatchDemoBreak`: aynı oturum 4 dk 40 sn'dir molada (mola ekranı görüntüsü için).
        if arguments.contains("-FokusWatchDemoBreak") {
            _ = try? FocusActions.togglePause(now: now.addingTimeInterval(-4 * 60 - 40))
        }
    }
    #endif

    /// Yerel → bellek içi sırasıyla düşer; açılışta asla çökmez. Depo App Group'ta durur ki komplikasyon
    /// uzantısı okuyabilsin.
    ///
    /// Neden CloudKit yok: 1.0'da depo `ubiquityIdentityToken != nil` koşuluyla CloudKit'e bağlanmaya
    /// çalışıyordu; watchOS'ta bu değer HER ZAMAN `nil`dir (Apple QA1935), yani depo zaten hep yereldi ve
    /// saatte yapılan oturumlar telefona hiç ulaşmıyordu. Artık kayıtlar `WatchConnectivity` ile taşınır;
    /// saatin ayrıca CloudKit'e yazması aynı `id`'li çift kayıtlar üretirdi.
    private static func makeContainer() -> ModelContainer {
        let storeURL = FokusAppGroup.resolveStoreURL()
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
