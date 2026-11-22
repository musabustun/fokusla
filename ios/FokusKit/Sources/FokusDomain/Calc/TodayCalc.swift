import Foundation

/// Bugün ekranının hesapları — SAF fonksiyonlar (SwiftUI/SwiftData yok). Web
/// `web/src/domain/calc/today.ts` karşılığı; Bugün'e özgü birleştirme/seçim mantığıdır, asıl hesaplar
/// `FocusCalc`, `TasksCalc`, `TestsCalc`, `BooksCalc` ve `DailyGoalCalc`'tan gelir.
///
/// Kurallar: "şimdi" `now`, takvim günü `today` (YEREL) ve `calendar` parametredir; silinmiş kayıtlar
/// her fonksiyonda yok sayılır; kullanıcıya görünen metin yalnızca `Greeting.text`'tedir.
public enum TodayCalc {
    // MARK: - Selam

    /// Günün bölümü. Saat aralıkları (yerel, [başlangıç, bitiş)): sabah 05–12, öğleden sonra 12–18,
    /// akşam 18–22, gece 22–05.
    public enum Greeting: String, Sendable, Equatable, CaseIterable {
        case morning, afternoon, evening, night

        public var text: String {
            switch self {
            case .morning: "Günaydın"
            case .afternoon: "İyi günler"
            case .evening: "İyi akşamlar"
            case .night: "İyi geceler"
            }
        }
    }

    public static let morningStartHour = 5
    public static let afternoonStartHour = 12
    public static let eveningStartHour = 18
    public static let nightStartHour = 22

    /// `now`'ın YEREL saatine göre selam.
    public static func greeting(now: Date, calendar: Calendar = .current) -> Greeting {
        let hour = calendar.component(.hour, from: now)
        if hour >= nightStartHour || hour < morningStartHour { return .night }
        if hour >= eveningStartHour { return .evening }
        if hour >= afternoonStartHour { return .afternoon }
        return .morning
    }

    // MARK: - Odak

    /// Haftalık mini grafikte gösterilen gün sayısı (bugün dahil).
    public static let chartDays = 7

    public struct FocusSummary: Sendable, Equatable {
        /// Bugün (yerel gün) toplam odak (ms); gece yarısını aşan segmentler bölünür, açık segment `now`'a kadar.
        public var totalMs: Double
        /// Bugüne dokunan (bugün başlayan, hâlâ açık ya da bugün odak süresi olan) silinmemiş oturum sayısı.
        public var sessionCount: Int
        /// Bu oturumların KAPANMIŞ odak segmentlerinin ortalaması (ms); yoksa 0.
        public var averageFocusMs: Double

        public init(totalMs: Double, sessionCount: Int, averageFocusMs: Double) {
            self.totalMs = totalMs
            self.sessionCount = sessionCount
            self.averageFocusMs = averageFocusMs
        }
    }

    /// Bugünün odak özeti. `sessions`/`segments` en az bugüne dokunan oturumları içermelidir (fazlası zarar vermez).
    public static func focusSummary(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        today: ISODate, now: Date, calendar: Calendar = .current
    ) -> FocusSummary {
        let live = sessions.filter { $0.deletedAt == nil }
        let touching = live.filter {
            touchesDay($0, segments: segments, today: today, now: now, calendar: calendar)
        }
        let ids = Set(touching.map(\.id))
        let todaySegments = segments.filter { $0.sessionId.map(ids.contains) ?? false }
        return FocusSummary(
            totalMs: totalMs(sessions: sessions, segments: segments, day: today, now: now, calendar: calendar),
            sessionCount: touching.count,
            averageFocusMs: FocusCalc.computeSessionStats(todaySegments, now: now).averageFocusMs)
    }

    private static func totalMs(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        day: ISODate, now: Date, calendar: Calendar
    ) -> Double {
        (try? FocusCalc.dailyFocusTotalMs(
            sessions: sessions, segments: segments, day: day, now: now, calendar: calendar)) ?? 0
    }

    private static func touchesDay(
        _ session: FocusSessionSnapshot, segments: [FocusSegmentSnapshot],
        today: ISODate, now: Date, calendar: Calendar
    ) -> Bool {
        if session.endedAt == nil { return true }
        if Identifiers.isoDate(session.startedAt, calendar: calendar) == today { return true }
        let own = segments.filter { $0.sessionId == session.id }
        return totalMs(sessions: [session], segments: own, day: today, now: now, calendar: calendar) > 0
    }

    /// Açık oturumun anlık durumu.
    public struct ActiveFocus: Sendable, Equatable {
        public enum Phase: String, Sendable, Equatable { case focus, `break` }
        public var phase: Phase
        /// Oturumun toplam odak süresi (ms), açık odak segmenti `now`'a kadar.
        public var sessionFocusMs: Double

        public init(phase: Phase, sessionFocusMs: Double) {
            self.phase = phase
            self.sessionFocusMs = sessionFocusMs
        }
    }

    /// Açık oturumun canlı durumu. Oturum yoksa, bitmiş ya da silinmişse `nil`. `segments` başka
    /// oturumlara ait segmentler de içerebilir; yalnızca bu oturumunkiler sayılır.
    public static func activeFocus(
        session: FocusSessionSnapshot?, segments: [FocusSegmentSnapshot], now: Date
    ) -> ActiveFocus? {
        guard let session, session.deletedAt == nil else { return nil }
        let own = segments.filter { $0.sessionId == session.id }
        let phase: ActiveFocus.Phase
        switch FocusCalc.focusPhase(session: session, segments: own) {
        case .focus: phase = .focus
        case .break: phase = .break
        case .ended: return nil
        }
        return ActiveFocus(phase: phase, sessionFocusMs: FocusCalc.computeSessionStats(own, now: now).focusMs)
    }

    /// Son `days` günün (bugün dahil, ESKİDEN YENİYE) günlük odak toplamları. `days <= 0` → `[]`.
    public static func recentFocusTotals(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        now: Date, days: Int = chartDays, calendar: Calendar = .current
    ) -> [FocusCalc.DailyFocusTotal] {
        let list = FocusCalc.recentDays(now: now, count: days, calendar: calendar)
        return (try? FocusCalc.dailyFocusTotals(
            sessions: sessions, segments: segments, days: list, now: now, calendar: calendar)) ?? []
    }

    // MARK: - Görevler

    /// Görevin Bugün'deki grubu (görüntü sırası budur).
    public enum TaskGroup: String, Sendable, Equatable, CaseIterable {
        case overdue, routine, dueToday, upcoming

        /// Bugünün planına (ilerleme sayısına) dahil mi? Yaklaşanlar dahil değildir.
        public var isCounted: Bool { self != .upcoming }
    }

    public struct TaskItem: Sendable, Equatable, Identifiable {
        public var task: TaskSnapshot
        public var group: TaskGroup
        /// `today` itibarıyla tamamlanmış mı.
        public var isDone: Bool
        public var id: UUID { task.id }

        public init(task: TaskSnapshot, group: TaskGroup, isDone: Bool) {
            self.task = task
            self.group = group
            self.isDone = isDone
        }
    }

    public struct TaskOverview: Sendable, Equatable {
        /// Sıra: gecikenler, rutinler, bugün teslim/tarihsiz, yaklaşanlar.
        public var items: [TaskItem]
        /// Bugün yapılacaklar (gecikmiş + rutin + bugün teslim) sayısı; yaklaşanlar hariç.
        public var totalCount: Int
        /// Bunlardan tamamlananlar.
        public var doneCount: Int

        public var progress: Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }
        public var isComplete: Bool { totalCount > 0 && doneCount == totalCount }

        public init(items: [TaskItem], totalCount: Int, doneCount: Int) {
            self.items = items
            self.totalCount = totalCount
            self.doneCount = doneCount
        }
    }

    /// Bugünün görev özeti (`TasksCalc.agenda` üzerine).
    public static func taskOverview(
        tasks: [TaskSnapshot], completions: [TaskCompletionSnapshot],
        today: ISODate, calendar: Calendar = .current
    ) -> TaskOverview {
        let agenda = TasksCalc.agenda(for: today, tasks: tasks, calendar: calendar)
        let grouped: [(TaskGroup, [TaskSnapshot])] = [
            (.overdue, agenda.overdue), (.routine, agenda.routines),
            (.dueToday, agenda.dueToday), (.upcoming, agenda.upcoming),
        ]
        let items = grouped.flatMap { group, list in
            list.map { task in
                TaskItem(
                    task: task, group: group,
                    isDone: TasksCalc.isCompleted(task, completions: completions, on: today, calendar: calendar))
            }
        }
        let counted = items.filter(\.group.isCounted)
        return TaskOverview(items: items, totalCount: counted.count, doneCount: counted.filter(\.isDone).count)
    }

    // MARK: - Testler

    /// "Son testler" penceresi: son 7 gün (bugün dahil).
    public static let recentTestsWindowDays = 7
    /// Bugün'de gösterilen en zayıf konu sayısı.
    public static let weakTopicLimit = 3

    public struct RecentTests: Sendable, Equatable {
        /// Bugün (yerel gün) çözülen soru sayısı.
        public var todayQuestions: Int
        /// Son `windowDays` günün özeti (`TestsCalc.summarize`).
        public var window: TestSummary
        /// Silinmemiş tüm test sonuçlarının sayısı (boş durum için).
        public var allTimeCount: Int

        public init(todayQuestions: Int, window: TestSummary, allTimeCount: Int) {
            self.todayQuestions = todayQuestions
            self.window = window
            self.allTimeCount = allTimeCount
        }
    }

    /// Bugün ve son `windowDays` gün (bugün dahil; en az 1) çözülen testlerin özeti.
    public static func recentTests(
        results: [TestResultSnapshot], today: ISODate,
        windowDays: Int = recentTestsWindowDays, calendar: Calendar = .current
    ) -> RecentTests {
        let live = results.filter { $0.deletedAt == nil }
        let windowStart = TasksCalc.addDays(today, -(Swift.max(1, windowDays) - 1))
        func day(_ result: TestResultSnapshot) -> ISODate {
            Identifiers.isoDate(result.takenAt, calendar: calendar)
        }
        let inWindow = live.filter { day($0) >= windowStart && day($0) <= today }
        let todayQuestions = inWindow.filter { day($0) == today }
            .reduce(0) { $0 + TestsCalc.questionCount(correct: $1.correct, wrong: $1.wrong, blank: $1.blank) }
        return RecentTests(
            todayQuestions: todayQuestions, window: TestsCalc.summarize(inWindow), allTimeCount: live.count)
    }

    /// Tüm zamanların en zayıf `limit` konusu (`TestsCalc.findWeakestTopics`, varsayılan soru eşiği).
    /// Silinmiş sonuçlar sayılmaz.
    public static func weakestTopics(
        results: [TestResultSnapshot], limit: Int = weakTopicLimit
    ) -> [WeakTopic] {
        TestsCalc.findWeakestTopics(
            TestsCalc.summarizeByTopic(results.filter { $0.deletedAt == nil }), limit: limit)
    }

    // MARK: - Kitaplar

    /// Bugün'de gösterilen en fazla kitap sayısı.
    public static let bookLimit = 3

    /// Devam eden kitaplar: önce `inProgress`, sonra `notStarted`; her grupta girdi sırası korunur
    /// (`BooksCalc.summarizeBooks` son etkinliğe göre sıralar). Bitmiş/arşivlenmiş hariç.
    public static func booksInProgress(
        _ summaries: [BooksCalc.BookSummary], limit: Int = bookLimit
    ) -> [BooksCalc.BookSummary] {
        let started = summaries.filter { $0.status == .inProgress }
        let notStarted = summaries.filter { $0.status == .notStarted }
        return Array((started + notStarted).prefix(Swift.max(0, limit)))
    }
}
