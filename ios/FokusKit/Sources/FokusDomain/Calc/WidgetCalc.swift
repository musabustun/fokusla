import Foundation

/// Ana ekran / kilit ekranı widget'ları için SAF hesaplar: bugünkü odak özeti (+ hedef halkası),
/// bugünün görev listesi ve timeline tarihleri. `Date()` çağrılmaz; `now` dışarıdan gelir.
///
/// Odak sürerken toplam saniye saniye büyür; widget bunu `Text(timerInterval:)` ile sisteme saydırır
/// (`FocusSummary.timerStart`), halka ise `timelineDates` ile sık aralıklı girdilerle yenilenir.
public enum WidgetCalc {
    // MARK: - Odak özeti

    public struct FocusSummary: Sendable, Equatable {
        /// Bugünkü toplam odak (ms), `now` anındaki değer.
        public var focusMs: Double
        /// Şu anda açık bir ODAK segmenti akıyor mu? (Molada false.)
        public var isRunning: Bool
        /// Günlük hedef durumu; hedef kapalıysa `nil`.
        public var goal: DailyGoalCalc.Progress?
        /// Akarken toplamı sistemin saydırması için sanal başlangıç (`now − focusMs`); durağanken `nil`.
        public var timerStart: Date?

        public init(focusMs: Double, isRunning: Bool, goal: DailyGoalCalc.Progress?, timerStart: Date?) {
            self.focusMs = focusMs
            self.isRunning = isRunning
            self.goal = goal
            self.timerStart = timerStart
        }

        /// Halka oranı (0–1); hedef yoksa 0.
        public var ratio: Double { goal?.ratio ?? 0 }
    }

    public static func focusSummary(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        goalMinutes: Int?, now: Date, calendar: Calendar = .current
    ) -> FocusSummary {
        let day = Identifiers.isoDate(now, calendar: calendar)
        let focusMs =
            (try? FocusCalc.dailyFocusTotalMs(
                sessions: sessions, segments: segments, day: day, now: now, calendar: calendar)) ?? 0
        let running =
            FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)?.phase == .focus
        return FocusSummary(
            focusMs: focusMs,
            isRunning: running,
            goal: DailyGoalCalc.progress(focusMs: focusMs, goalMinutes: goalMinutes),
            timerStart: running ? now.addingTimeInterval(-focusMs / 1000) : nil)
    }

    // MARK: - Timeline

    /// Odak akarken girdi aralığı ve sayısı (halka bu aralıkla ilerler).
    public static let runningStepMinutes = 5
    public static let runningEntryCount = 12

    public struct TimelinePlan: Sendable, Equatable {
        /// Girdi tarihleri (artan; ilki `now`).
        public var entries: [Date]
        /// Son girdiden sonra yeniden istenecek an (`.after(date)` politikası).
        public var reloadAfter: Date
    }

    /// Akıyorsa 5 dk aralıklı 12 girdi (1 saat) + sonunda yenile; durağansa tek girdi ve ertesi gün
    /// başlangıcında yenile (toplam sıfırlanır). Başlat/duraklat/görev değişimi zaten
    /// `reloadAllTimelines` ile anında yenilenir.
    public static func timelinePlan(isRunning: Bool, now: Date, calendar: Calendar = .current) -> TimelinePlan {
        let midnight = nextMidnight(after: now, calendar: calendar)
        guard isRunning else { return TimelinePlan(entries: [now], reloadAfter: midnight) }
        let step = TimeInterval(runningStepMinutes * 60)
        let entries = (0..<runningEntryCount).map { now.addingTimeInterval(step * Double($0)) }
        let last = entries.last ?? now
        return TimelinePlan(entries: entries.filter { $0 < midnight }, reloadAfter: Swift.min(last.addingTimeInterval(step), midnight))
    }

    public static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(86_400)
    }

    // MARK: - Görevler

    public struct TaskItem: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var title: String
        public var isDone: Bool
        /// Bugün işaretlenebilir mi (rutin bugün planlı değilse false).
        public var canToggle: Bool
        public var subjectName: String?
        /// "Bugün" / "Yarın" / "2 gün gecikti" gibi (yalnızca ödevlerde).
        public var dueText: String?
        public var isOverdue: Bool

        public init(
            id: UUID, title: String, isDone: Bool, canToggle: Bool, subjectName: String?,
            dueText: String?, isOverdue: Bool
        ) {
            self.id = id
            self.title = title
            self.isDone = isDone
            self.canToggle = canToggle
            self.subjectName = subjectName
            self.dueText = dueText
            self.isOverdue = isOverdue
        }
    }

    public struct TaskList: Sendable, Equatable {
        /// Önce açık olanlar (Görevler ekranındaki sırayla), sonra tamamlananlar.
        public var items: [TaskItem]
        public var done: Int
        public var total: Int

        public init(items: [TaskItem], done: Int, total: Int) {
            self.items = items
            self.done = done
            self.total = total
        }

        /// Sıradaki (açık ve işaretlenebilir) ilk görev.
        public var next: TaskItem? { items.first { !$0.isDone && $0.canToggle } }
        public var isComplete: Bool { total > 0 && done == total }
    }

    /// Bugünün planı: rutinler + geciken + bugün teslim ödevler (Görevler "Bugün" görünümüyle aynı kaynak).
    public static func todayTasks(
        tasks: [TaskSnapshot], completions: [TaskCompletionSnapshot], subjectNames: [UUID: String],
        now: Date, calendar: Calendar = .current
    ) -> TaskList {
        let context = TaskViews.Context(
            completions: completions, today: Identifiers.isoDate(now, calendar: calendar),
            subjectNames: subjectNames, calendar: calendar)
        let result = TaskViews.today(tasks, context: context, hideCompleted: false)
        let planned = result.sections.filter { ["routines", "overdue", "dueToday"].contains($0.key) }
            .flatMap(\.rows)
        let items = planned.map { row in
            TaskItem(
                id: row.id, title: row.task.title, isDone: row.isDone, canToggle: row.canToggle,
                subjectName: row.subjectName, dueText: row.due?.text, isOverdue: row.due?.isOverdue ?? false)
        }
        let open = items.filter { !$0.isDone }
        let finished = items.filter(\.isDone)
        return TaskList(items: open + finished, done: finished.count, total: items.count)
    }
}
