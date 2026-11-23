#if DEBUG
import FokusData
import FokusDomain
import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "store-listing-demo")

/// Yalnızca DEBUG: App Store ekran görüntüleri için gerçekçi demo verisi. `-FokusDemoData` VE `-FokusUITestMode`
/// birlikte verilince (bellek içi depo; üretim deposuna asla dokunmaz) tamamlanmış profil, ders/konu bazlı test
/// sonuçları, son 7 günün odak geçmişi, rutin + ödev görevleri, kitap ilerlemeleri ve günlük hedef eklenir.
/// `-FokusDemoOpenSession` ek olarak "şu an" açık bir odak oturumu başlatır (tam ekran odak görüntüsü için).
/// Müfredat tohumlandıktan SONRA çağrılır (katalog derslerine bağlanır). İdempotenttir.
/// (`-FokusDemoData` tek başına, UI testi olmadan, `DebugDemoData`'nın hafif widget verisini ekler.)
enum StoreListingDemoData {
    static let openSessionArgument = "-FokusDemoOpenSession"

    @MainActor
    static func seedIfRequested(
        container: ModelContainer, arguments: [String] = ProcessInfo.processInfo.arguments, now: Date = .now
    ) {
        guard arguments.contains(DebugDemoData.launchArgument),
            arguments.contains(AppEnvironment.uiTestLaunchArgument)
        else { return }
        let context = container.mainContext
        do {
            let profiles = ProfileRepository(context: context)
            guard try profiles.current() == nil else { return }
            try profiles.completeOnboarding(field: .say, appleUserId: nil, displayName: "Beyza", now: now)
            try profiles.setDailyFocusGoal(minutes: 240, now: now)
            let subjects = try EntityStore<Subject>(context: context).all()
            let topics = try EntityStore<Topic>(context: context).all()
            let catalog = Catalog(subjects: subjects, topics: topics)
            let books = try seedBooks(context: context, catalog: catalog, now: now)
            try seedTests(context: context, catalog: catalog, books: books, now: now)
            try seedTasks(context: context, catalog: catalog, now: now)
            try seedFocusHistory(context: context, catalog: catalog, now: now)
            if arguments.contains(openSessionArgument) {
                try FocusRepository(context: context).start(subjectId: catalog.subject("tyt-matematik")?.id, now: now.addingTimeInterval(-23 * 60))
            }
        } catch {
            logger.error("Mağaza demo verisi eklenemedi: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Katalog erişimi

    private struct Catalog {
        let subjects: [Subject]
        let topics: [Topic]

        func subject(_ key: String) -> Subject? { subjects.first { $0.catalogKey == key } }

        func topic(_ subjectKey: String, _ index: Int) -> Topic? {
            guard let subject = subject(subjectKey) else { return nil }
            let list = topics.filter { $0.subjectId == subject.id }.sorted { $0.order < $1.order }
            return list.indices.contains(index) ? list[index] : nil
        }
    }

    private static func date(_ daysAgo: Int, hour: Int, minute: Int = 0, from now: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    // MARK: - Kitaplar

    @MainActor
    private static func seedBooks(context: ModelContext, catalog: Catalog, now: Date) throws -> [String: Book] {
        let repository = BooksRepository(context: context)
        let specs: [(String, String, String, BookKind, BookUnit, Int, [(Int, Int)])] = [
            // (başlık, yayınevi, ders, tür, birim, toplam, [(kaç gün önce, ulaşılan)])
            ("TYT Matematik Soru Bankası", "Gece Yayınları", "tyt-matematik", .questionBank, .test, 120, [(14, 30), (7, 58), (1, 74)]),
            ("Fizik Konu Anlatımı", "Doruk Yayınları", "tyt-fizik", .lecture, .page, 320, [(10, 80), (3, 150)]),
            ("Paragraf Kampı", "Sınav Pusulası", "tyt-turkce", .questionBank, .test, 60, [(6, 20), (0, 36)]),
            ("Kimya Fasikülleri", "Ankara Eğitim", "tyt-kimya", .lecture, .page, 180, [(5, 45), (2, 72)]),
        ]
        var created: [String: Book] = [:]
        for spec in specs {
            let book = try repository.create(
                BookInput(
                    title: spec.0, publisher: spec.1, kind: spec.3, subjectId: catalog.subject(spec.2)?.id,
                    unit: spec.4, totalUnits: spec.5),
                now: date(spec.6.first?.0 ?? 0, hour: 9, from: now))
            for (daysAgo, reached) in spec.6 {
                try repository.addProgress(bookId: book.id, reachedUnit: reached, now: date(daysAgo, hour: 21, from: now))
            }
            created[spec.2] = book
        }
        return created
    }

    // MARK: - Test sonuçları

    @MainActor
    private static func seedTests(
        context: ModelContext, catalog: Catalog, books: [String: Book], now: Date
    ) throws {
        let repository = AnalysisRepository(context: context)
        // (kaç gün önce, ders, konu sırası, doğru, yanlış, boş) — matematik zamanla yükselir, geometri zayıf kalır.
        let rows: [(Int, String, Int, Int, Int, Int)] = [
            (13, "tyt-matematik", 0, 8, 9, 3), (11, "tyt-turkce", 0, 14, 4, 2),
            (9, "tyt-matematik", 1, 10, 8, 2), (8, "tyt-geometri", 0, 6, 8, 4),
            (6, "tyt-fizik", 0, 7, 5, 2), (5, "tyt-matematik", 2, 12, 6, 2),
            (4, "tyt-kimya", 0, 6, 4, 2), (3, "tyt-turkce", 1, 16, 3, 1),
            (2, "tyt-geometri", 1, 7, 9, 2), (1, "tyt-matematik", 3, 14, 4, 2),
            (0, "tyt-matematik", 0, 16, 3, 1), (0, "tyt-turkce", 2, 17, 2, 1),
        ]
        for row in rows {
            guard let subject = catalog.subject(row.1) else { continue }
            let when = date(row.0, hour: row.0 == 0 ? 11 : 17, from: now)
            try repository.addResult(
                TestResultForm.Input(
                    subjectId: subject.id, topicId: catalog.topic(row.1, row.2)?.id, bookId: books[row.1]?.id,
                    correct: row.3, wrong: row.4, blank: row.5, date: when),
                now: when)
        }
    }

    // MARK: - Görevler

    @MainActor
    private static func seedTasks(context: ModelContext, catalog: Catalog, now: Date) throws {
        let tasks = TasksRepository(context: context)
        let today = Identifiers.isoDate(now)
        func day(_ offset: Int) -> ISODate {
            Identifiers.isoDate(Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now)
        }
        let daily = RecurrenceRule(frequency: .daily)
        let routines: [(String, String?, Int?, String?)] = [
            ("Paragraf 20 soru", "tyt-turkce", 20, "soru"),
            ("Kelime ezberi", nil, nil, nil),
            ("Matematik problem 30 soru", "tyt-matematik", 30, "soru"),
        ]
        var created: [StudyTask] = []
        for item in routines {
            created.append(
                try tasks.create(
                    TaskValues(
                        kind: .routine, title: item.0, subjectId: item.1.flatMap { catalog.subject($0)?.id },
                        recurrence: daily, targetQuantity: item.2, quantityUnit: item.3),
                    today: today, now: now.addingTimeInterval(-10 * 86_400)))
        }
        // Bugün: ilk rutin yapıldı; ikincisi seri kazanması için son günlerde yapıldı.
        try tasks.toggleCompletion(created[0], on: today, now: now)
        for offset in 1...4 { try tasks.toggleCompletion(created[0], on: day(-offset), now: now) }
        for offset in 1...2 { try tasks.toggleCompletion(created[1], on: day(-offset), now: now) }
        _ = try tasks.create(
            TaskValues(kind: .assignment, title: "Fizik deneme sınavı", subjectId: catalog.subject("tyt-fizik")?.id, dueDate: day(1)),
            today: today, now: now.addingTimeInterval(-3 * 86_400))
        _ = try tasks.create(
            TaskValues(kind: .assignment, title: "Kimya fasikül testi", subjectId: catalog.subject("tyt-kimya")?.id, dueDate: day(3)),
            today: today, now: now.addingTimeInterval(-2 * 86_400))
        _ = try tasks.create(
            TaskValues(kind: .assignment, title: "Geometri üçgenler 40 soru", subjectId: catalog.subject("tyt-geometri")?.id, dueDate: day(5)),
            today: today, now: now.addingTimeInterval(-86_400))
    }

    // MARK: - Odak geçmişi

    @MainActor
    private static func seedFocusHistory(context: ModelContext, catalog: Catalog, now: Date) throws {
        let focus = FocusRepository(context: context)
        let subjectKeys = ["tyt-matematik", "tyt-turkce", "tyt-fizik", "tyt-geometri", "tyt-kimya", "tyt-matematik", "tyt-turkce"]
        /// Her oturum: (başlangıç saati, odak dk, mola dk, odak dk) — bitiş = toplam.
        func session(_ daysAgo: Int, hour: Int, subject: String?, parts: [Int]) throws {
            var cursor = date(daysAgo, hour: hour, from: now)
            let created = try focus.start(subjectId: subject.flatMap { catalog.subject($0)?.id }, now: cursor)
            for (index, minutes) in parts.enumerated() {
                cursor = cursor.addingTimeInterval(Double(minutes) * 60)
                if index == parts.count - 1 {
                    try focus.finish(sessionId: created.id, now: cursor)
                } else if index % 2 == 0 {
                    try focus.pause(sessionId: created.id, now: cursor)
                } else {
                    try focus.resume(sessionId: created.id, now: cursor)
                }
            }
        }
        // Bugün (öğleden önce biten iki oturum) + önceki altı gün.
        let todayStart = Calendar.current.component(.hour, from: now)
        let morning = max(6, min(todayStart - 4, 9))
        try session(0, hour: morning, subject: "tyt-matematik", parts: [50, 8, 40])
        try session(0, hour: morning + 2, subject: "tyt-turkce", parts: [45, 7, 30])
        let history: [(Int, Int, [Int])] = [
            (1, 16, [55, 10, 50, 8, 35]), (2, 17, [40, 8, 45]), (3, 15, [60, 10, 55, 10, 40]),
            (4, 18, [35, 6, 30]), (5, 16, [50, 9, 45, 8, 30]), (6, 17, [45, 8, 40]),
        ]
        for (index, item) in history.enumerated() {
            try session(item.0, hour: item.1, subject: subjectKeys[index], parts: item.2)
        }
    }
}
#endif
