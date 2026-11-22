import FokusData
import FokusDomain
import Foundation
import SwiftData

/// UI testleri ve ekran görüntüleri için örnek veri (yalnızca DEBUG + `-FokusUITestMode`).
/// `-FokusUITestTodaySeed tasks` → yalnızca iki görev (rutin + ödev);
/// `-FokusUITestTodaySeed full` → hedef, odak geçmişi, görevler, testler ve kitaplar.
enum TodayUITestSeed {
    static let argumentKey = "FokusUITestTodaySeed"

    @MainActor
    static func applyIfRequested(context: ModelContext, now: Date = .now) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-FokusUITestMode"),
            let mode = UserDefaults.standard.string(forKey: argumentKey)
        else { return }
        let taskStore = EntityStore<StudyTask>(context: context)
        guard (try? taskStore.all().isEmpty) == true else { return }
        seedTasks(taskStore, full: mode == "full", now: now)
        if mode == "full" {
            seedProfile(context: context)
            seedFocus(context: context, now: now)
            seedTests(context: context, now: now)
            seedBooks(context: context, now: now)
        }
        try? taskStore.save()
        try? context.save()
        #endif
    }

    #if DEBUG
    private static func day(_ offset: Int, from now: Date) -> ISODate {
        Identifiers.isoDate(Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now)
    }

    @MainActor
    private static func seedTasks(_ store: EntityStore<StudyTask>, full: Bool, now: Date) {
        let created = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        store.insert(
            StudyTask(
                title: "Paragraf 20 soru", kind: .routine,
                recurrence: RecurrenceRule(frequency: .daily), order: 0),
            now: created)
        store.insert(
            StudyTask(title: "Fizik ödevi", kind: .assignment, dueDate: day(1, from: now), order: 1),
            now: created)
        guard full else { return }
        store.insert(
            StudyTask(
                title: "Kelime çalış", kind: .routine,
                recurrence: RecurrenceRule(frequency: .daily), order: 2),
            now: created)
        store.insert(
            StudyTask(title: "Matematik denemesi", kind: .assignment, dueDate: day(-1, from: now), order: 3),
            now: created)
        store.insert(
            StudyTask(title: "Kimya fasikülü", kind: .assignment, dueDate: day(4, from: now), order: 4),
            now: created)
    }

    @MainActor
    private static func seedProfile(context: ModelContext) {
        let repository = ProfileRepository(context: context)
        try? repository.setDisplayName("Elif")
        try? repository.setDailyFocusGoal(minutes: 240)
    }

    @MainActor
    private static func seedFocus(context: ModelContext, now: Date) {
        let sessions = EntityStore<FocusSession>(context: context)
        let segments = EntityStore<FocusSegment>(context: context)
        let minute: TimeInterval = 60
        func add(start: Date, parts: [(FocusSegmentKind, Double)], ended: Bool) {
            let session = sessions.insert(FocusSession(subjectId: nil, startedAt: start, endedAt: nil), now: start)
            var cursor = start
            for (index, part) in parts.enumerated() {
                let end = cursor.addingTimeInterval(part.1 * minute)
                let isLast = index == parts.count - 1
                segments.insert(
                    FocusSegment(
                        sessionId: session.id, kind: part.0, startedAt: cursor,
                        endedAt: isLast && !ended ? nil : end),
                    now: cursor)
                cursor = end
            }
            if ended { session.endedAt = cursor }
        }
        // Bugün: iki bitmiş oturum (toplam ≈ 2 sa 40 dk).
        add(start: now.addingTimeInterval(-200 * minute), parts: [(.focus, 50), (.break, 10), (.focus, 45)], ended: true)
        add(start: now.addingTimeInterval(-80 * minute), parts: [(.focus, 40), (.break, 8), (.focus, 25)], ended: true)
        let calendar = Calendar.current
        for (daysAgo, focus) in [(1, 150.0), (2, 95.0), (3, 210.0), (5, 60.0), (6, 130.0)] {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                let start = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date)
            else { continue }
            add(start: start, parts: [(.focus, focus)], ended: true)
        }
        try? sessions.save()
    }

    @MainActor
    private static func seedTests(context: ModelContext, now: Date) {
        let store = EntityStore<TestResult>(context: context)
        let subjects = (try? EntityStore<Subject>(context: context).all()) ?? []
        let topics = (try? EntityStore<Topic>(context: context).all()) ?? []
        guard let math = subjects.first(where: { $0.catalogKey == "tyt-matematik" }),
            let turkish = subjects.first(where: { $0.catalogKey == "tyt-turkce" })
        else { return }
        let mathTopics = topics.filter { $0.subjectId == math.id }.sorted { $0.order < $1.order }
        let turkishTopics = topics.filter { $0.subjectId == turkish.id }.sorted { $0.order < $1.order }
        guard mathTopics.count >= 2, let turkishTopic = turkishTopics.first else { return }
        let calendar = Calendar.current
        func add(_ subject: Subject, _ topic: Topic, daysAgo: Int, _ c: Int, _ w: Int, _ b: Int) {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                let takenAt = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            else { return }
            store.insert(
                TestResult(subjectId: subject.id, topicId: topic.id, takenAt: takenAt, correct: c, wrong: w, blank: b),
                now: takenAt)
        }
        add(math, mathTopics[0], daysAgo: 0, 12, 6, 2)
        add(math, mathTopics[0], daysAgo: 2, 10, 8, 2)
        add(math, mathTopics[1], daysAgo: 3, 9, 9, 2)
        add(turkish, turkishTopic, daysAgo: 1, 17, 2, 1)
        try? store.save()
    }

    @MainActor
    private static func seedBooks(context: ModelContext, now: Date) {
        let books = EntityStore<Book>(context: context)
        let progress = EntityStore<BookProgress>(context: context)
        func add(_ title: String, unit: BookUnit, total: Int, reached: Int) {
            let recorded = now.addingTimeInterval(-86_400)
            let book = books.insert(Book(title: title, kind: .questionBank, unit: unit, totalUnits: total), now: recorded)
            progress.insert(BookProgress(bookId: book.id, reachedUnit: reached, recordedAt: recorded), now: recorded)
        }
        add("TYT Matematik Soru Bankası", unit: .test, total: 120, reached: 74)
        add("Fizik Konu Anlatımı", unit: .page, total: 320, reached: 150)
        try? books.save()
    }
    #endif
}
