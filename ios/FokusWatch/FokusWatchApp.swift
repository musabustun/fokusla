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
        if arguments.contains("-FokusWatchDemoStats") { seedStatsDemo(now: now) }
        guard arguments.contains("-FokusWatchDemoSession") else { return }
        _ = try? FocusActions.start(subjectId: nil, now: now.addingTimeInterval(-23 * 60 - 14))
        // `-FokusWatchDemoBreak`: aynı oturum 4 dk 40 sn'dir molada (mola ekranı görüntüsü için).
        if arguments.contains("-FokusWatchDemoBreak") {
            _ = try? FocusActions.togglePause(now: now.addingTimeInterval(-4 * 60 - 40))
        }
    }

    /// `-FokusWatchDemoStats`: son 7 günde bitmiş oturumlar + 3 saatlik hedef (istatistik ekranı için).
    private static func seedStatsDemo(now: Date) {
        guard let context = try? FokusSystem.context() else { return }
        let profiles = ProfileRepository(context: context)
        _ = try? profiles.completeOnboarding(field: .say, appleUserId: nil, displayName: nil, now: now)
        try? profiles.setDailyFocusGoal(minutes: 180, now: now)
        let repository = FocusRepository(context: context)
        let minutesPerDay: [Double] = [95, 140, 60, 185, 120, 30, 0]
        for (index, minutes) in minutesPerDay.enumerated() where minutes > 0 {
            let start = now.addingTimeInterval(-Double(6 - index) * 86_400 - 5 * 3600)
            guard let session = try? repository.start(now: start) else { continue }
            _ = try? repository.finish(sessionId: session.id, now: start.addingTimeInterval(minutes * 60))
        }
        for (hoursAgo, minutes) in [(1.4, 40.0), (0.6, 25.0)] {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            guard let session = try? repository.start(now: start) else { continue }
            _ = try? repository.finish(sessionId: session.id, now: start.addingTimeInterval(minutes * 60))
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
