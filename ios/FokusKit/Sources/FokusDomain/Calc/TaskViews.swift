import Foundation

/// Görevler ekranının satır modeli ve "Bugün"/"Tümü" görünümleri — SAF. Web `features/tasks/rowModel.ts`
/// ve `views.ts` karşılığı. `TasksCalc` + `TaskFormatting` üzerine kuruludur; SwiftUI bilmez.
public enum TaskViews {
    /// Satırları üretmek için ortak bağlam.
    public struct Context: Sendable {
        public var completions: [TaskCompletionSnapshot]
        /// Yerel bugün (`ISODate`).
        public var today: ISODate
        /// `Subject.id` → ders adı.
        public var subjectNames: [UUID: String]
        public var calendar: Calendar

        public init(
            completions: [TaskCompletionSnapshot], today: ISODate, subjectNames: [UUID: String] = [:],
            calendar: Calendar = .current
        ) {
            self.completions = completions
            self.today = today
            self.subjectNames = subjectNames
            self.calendar = calendar
        }
    }

    /// Bir görev satırının ekranda gösterilecek, hesaplanmış hali.
    public struct RowModel: Sendable, Equatable, Identifiable {
        public var task: TaskSnapshot
        /// Bugün itibarıyla tamamlanmış mı (onay kutusu).
        public var isDone: Bool
        /// Bugün işaretlenebilir mi? (Planlı olmayan gündeki rutin: hayır.)
        public var canToggle: Bool
        public var subjectName: String?
        /// "50 soru" / "42/50 soru".
        public var quantity: String?
        /// Rutin serisi (yalnızca > 0 ise).
        public var streak: Int?
        /// Rutin tekrar metni ("Her gün"…); yalnızca `detailed` modda.
        public var recurrence: String?
        /// "Son 7 gün %57"; yalnızca `detailed` modda ve planlı gün varsa.
        public var rate: String?
        /// Ödevin son tarih metni ve gecikmiş olup olmadığı.
        public var due: Due?

        public var id: UUID { task.id }

        public struct Due: Sendable, Equatable {
            public var text: String
            public var isOverdue: Bool
        }
    }

    public struct Section: Sendable, Equatable, Identifiable {
        public var key: String
        public var title: String
        public var rows: [RowModel]
        public var id: String { key }
    }

    public struct ViewResult: Sendable, Equatable {
        public var sections: [Section]
        /// Gizleme uygulanmadan önce görünümde en az bir görev var mı?
        public var hasTasks: Bool
    }

    /// Bugünün planındaki (rutin + geciken + bugün teslim) tamamlanan / toplam görev sayısı.
    public struct Summary: Sendable, Equatable {
        public var done: Int
        public var total: Int
        /// 0–1; görev yoksa 0.
        public var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }
        public var isComplete: Bool { total > 0 && done == total }
    }

    // MARK: - Satır

    public static func row(_ task: TaskSnapshot, context: Context, detailed: Bool = false) -> RowModel {
        let isRoutine = task.kind == .routine
        let days = TasksCalc.daysUntilDue(task, today: context.today)
        let streak = isRoutine
            ? TasksCalc.routineStreak(
                task, completions: context.completions, today: context.today, calendar: context.calendar)
            : 0
        return RowModel(
            task: task,
            isDone: TasksCalc.isCompleted(
                task, completions: context.completions, on: context.today, calendar: context.calendar),
            canToggle: !isRoutine
                || TasksCalc.isScheduled(task, on: context.today, calendar: context.calendar),
            subjectName: task.subjectId.flatMap { context.subjectNames[$0] },
            quantity: TaskFormatting.quantityText(
                target: task.targetQuantity, actual: actualQuantity(task, context: context),
                unit: task.quantityUnit),
            streak: streak > 0 ? streak : nil,
            recurrence: detailed ? task.recurrence.map(TaskFormatting.recurrenceText) : nil,
            rate: detailed && isRoutine ? rateText(task, context: context) : nil,
            due: days.map {
                RowModel.Due(
                    text: TaskFormatting.dueText(daysUntil: $0),
                    isOverdue: TasksCalc.isOverdue(task, today: context.today))
            })
    }

    private static func actualQuantity(_ task: TaskSnapshot, context: Context) -> Int? {
        if task.kind == .assignment { return task.completedQuantity }
        return TasksCalc.findCompletion(context.completions, taskId: task.id, day: context.today)?.quantity
    }

    private static func rateText(_ task: TaskSnapshot, context: Context) -> String? {
        TasksCalc.completionRate(
            task, completions: context.completions, today: context.today, calendar: context.calendar
        ).rate.map { TaskFormatting.rateText($0) }
    }

    // MARK: - Görünümler

    private static func byOrder(_ a: TaskSnapshot, _ b: TaskSnapshot) -> Bool {
        if a.order != b.order { return a.order < b.order }
        return a.title.compare(b.title, locale: Locale(identifier: "tr_TR")) == .orderedAscending
    }

    /// "Bugün": Rutinler, Geciken, Bugün teslim, Yaklaşan (boş bölümler çıkarılır).
    public static func today(
        _ tasks: [TaskSnapshot], context: Context, hideCompleted: Bool
    ) -> ViewResult {
        let agenda = TasksCalc.agenda(for: context.today, tasks: tasks, calendar: context.calendar)
        func rows(_ list: [TaskSnapshot]) -> [RowModel] { list.map { row($0, context: context) } }
        return finish(
            [
                Section(key: "routines", title: "Rutinler", rows: rows(agenda.routines)),
                Section(key: "overdue", title: "Geciken", rows: rows(agenda.overdue)),
                Section(key: "dueToday", title: "Bugün teslim", rows: rows(agenda.dueToday)),
                Section(key: "upcoming", title: "Yaklaşan", rows: rows(agenda.upcoming)),
            ], hideCompleted: hideCompleted)
    }

    /// "Tümü": tüm rutinler (tekrar + seri + son 7 gün oranı), açık ödevler (son tarihe göre) ve
    /// tamamlanan ödevler (en yeni önce; gizleme açıkken çıkarılır). Rutinler her gün yenilenir;
    /// gizleme yalnızca tamamlanan ödevlere uygulanır.
    public static func all(
        _ tasks: [TaskSnapshot], context: Context, hideCompleted: Bool
    ) -> ViewResult {
        let live = tasks.filter { $0.deletedAt == nil }
        func rows(_ list: [TaskSnapshot]) -> [RowModel] {
            list.map { row($0, context: context, detailed: true) }
        }
        let routines = live.filter { $0.kind == .routine }.sorted(by: byOrder)
        let assignments = live.filter { $0.kind == .assignment }
        let open = assignments.filter { $0.completedAt == nil }
        let completed = assignments.filter { $0.completedAt != nil }.sorted {
            // En yeni tamamlanan önce; eşitlikte order/title.
            if $0.completedAt != $1.completedAt { return ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            return byOrder($0, $1)
        }

        var sections = [
            Section(key: "routines", title: "Rutinler", rows: rows(routines)),
            Section(
                key: "assignments", title: "Ödevler",
                rows: rows(TasksCalc.sortedByDueDate(open))),
        ].filter { !$0.rows.isEmpty }
        if !hideCompleted, !completed.isEmpty {
            sections.append(
                Section(key: "completed", title: "Tamamlanan ödevler", rows: rows(completed)))
        }
        return ViewResult(sections: sections, hasTasks: !live.isEmpty)
    }

    /// Bugünün planındaki (rutin + geciken + bugün teslim) tamamlanan / toplam sayısı.
    public static func summary(_ tasks: [TaskSnapshot], context: Context) -> Summary {
        let result = today(tasks, context: context, hideCompleted: false)
        let rows = result.sections.filter { ["routines", "overdue", "dueToday"].contains($0.key) }
            .flatMap(\.rows)
        return Summary(done: rows.filter(\.isDone).count, total: rows.count)
    }

    private static func finish(_ sections: [Section], hideCompleted: Bool) -> ViewResult {
        let hasTasks = sections.contains { !$0.rows.isEmpty }
        let visible = sections
            .map { section in
                var copy = section
                if hideCompleted { copy.rows = section.rows.filter { !$0.isDone } }
                return copy
            }
            .filter { !$0.rows.isEmpty }
        return ViewResult(sections: visible, hasTasks: hasTasks)
    }
}
