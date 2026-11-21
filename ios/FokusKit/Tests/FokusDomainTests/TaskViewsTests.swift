import Foundation
import Testing

@testable import FokusDomain

// Görev satır modeli ve görünümleri testleri — web `features/tasks/views.test.ts` vakaları (aynı
// adlar/değerler) + `rowModel.ts` davranışı. Saat dilimi Europe/Istanbul'a sabittir.

private let today = "2026-11-19"

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

private let testNamespace = UUID(uuidString: "1b6c7f0e-52a3-4d1b-9c3f-5a6d2e8f4b77")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

private let daily = RecurrenceRule(frequency: .daily)

private func task(
    _ title: String, kind: TaskKind = .assignment, order: Int = 0, dueDate: ISODate? = nil,
    completedAt: Date? = nil, recurrence: RecurrenceRule? = nil, deletedAt: Date? = nil,
    subjectId: UUID? = nil, targetQuantity: Int? = nil, quantityUnit: String? = nil,
    completedQuantity: Int? = nil
) -> TaskSnapshot {
    TaskSnapshot(
        id: uuid(title), title: title, kind: kind, order: order, dueDate: dueDate,
        recurrence: recurrence, completedAt: completedAt, startDate: nil,
        createdAt: local(2026, 11, 1), deletedAt: deletedAt, subjectId: subjectId,
        targetQuantity: targetQuantity, quantityUnit: quantityUnit,
        completedQuantity: completedQuantity)
}

private func routine(_ title: String, order: Int = 0, recurrence: RecurrenceRule = daily) -> TaskSnapshot {
    task(title, kind: .routine, order: order, recurrence: recurrence)
}

private func context(
    completions: [TaskCompletionSnapshot] = [], subjectNames: [UUID: String] = [:]
) -> TaskViews.Context {
    TaskViews.Context(
        completions: completions, today: today, subjectNames: subjectNames, calendar: calendar)
}

private func completion(
    _ taskTitle: String, day: ISODate = today, quantity: Int? = nil
) -> TaskCompletionSnapshot {
    TaskCompletionSnapshot(
        id: uuid("c-\(taskTitle)-\(day)"), taskId: uuid(taskTitle), date: day,
        completedAt: local(2026, 11, 19), quantity: quantity)
}

private func titles(_ result: TaskViews.ViewResult) -> [[String]] {
    result.sections.map { [$0.title] + $0.rows.map(\.task.title) }
}

// MARK: - all

private let allViewTasks: [TaskSnapshot] = [
    task("Çay", order: 2, dueDate: "2026-11-25"),
    task("Bal", order: 2, dueDate: "2026-11-25"),
    task("Ayva", order: 5, dueDate: "2026-11-20"),
    task("Tarihsiz", order: 0, dueDate: nil),
    task("Eski", dueDate: "2026-11-01", completedAt: local(2026, 11, 2)),
    task("Yeni", dueDate: "2026-11-10", completedAt: local(2026, 11, 12)),
    task("Silinmiş", dueDate: "2026-11-20", deletedAt: local(2026, 11, 3)),
    routine("Rutin B", order: 1),
    routine("Rutin A", order: 1),
]

@Test("all: rutinleri sıraya, ödevleri son tarihe, tamamlananları en yeni önce dizer")
private func allOrdering() {
    #expect(
        titles(TaskViews.all(allViewTasks, context: context(), hideCompleted: false)) == [
            ["Rutinler", "Rutin A", "Rutin B"],
            ["Ödevler", "Ayva", "Bal", "Çay", "Tarihsiz"],
            ["Tamamlanan ödevler", "Yeni", "Eski"],
        ])
}

@Test("all: gizlemede tamamlanan ödevleri çıkarır; görev yoksa hasTasks false")
private func allHideCompleted() {
    #expect(
        titles(TaskViews.all(allViewTasks, context: context(), hideCompleted: true)) == [
            ["Rutinler", "Rutin A", "Rutin B"],
            ["Ödevler", "Ayva", "Bal", "Çay", "Tarihsiz"],
        ])
    #expect(
        TaskViews.all([], context: context(), hideCompleted: false)
            == TaskViews.ViewResult(sections: [], hasTasks: false))
}

@Test("all: yalnızca tamamlanan ödev varken gizleme boş liste ama hasTasks true döner")
private func allOnlyCompletedHidden() {
    let result = TaskViews.all(
        [task("Bitti", completedAt: local(2026, 11, 12))], context: context(), hideCompleted: true)
    #expect(result.sections.isEmpty)
    #expect(result.hasTasks)
}

@Test("all: aynı anda tamamlanan ödevlerde sıra order/title ile belirlenir")
private func allCompletedTieBreak() {
    let same = local(2026, 11, 12)
    let result = TaskViews.all(
        [task("B", order: 1, completedAt: same), task("A", order: 1, completedAt: same)],
        context: context(), hideCompleted: false)
    #expect(titles(result) == [["Tamamlanan ödevler", "A", "B"]])
}

@Test("all: satırlar ayrıntılıdır (tekrar metni ve son 7 gün oranı)")
private func allRowsAreDetailed() {
    let result = TaskViews.all(
        [routine("Paragraf")], context: context(completions: [completion("Paragraf")]),
        hideCompleted: false)
    let row = result.sections[0].rows[0]
    #expect(row.recurrence == "Her gün")
    #expect(row.rate == "Son 7 gün %14")
}

// MARK: - today

@Test("today: boş bölümleri çıkarır ve gizlemede tamamlananları süzer")
private func todayHidesCompleted() {
    let tasks = [
        task("Açık", dueDate: today),
        task("Bitti", dueDate: today, completedAt: local(2026, 11, 19, 7)),
    ]
    #expect(
        titles(TaskViews.today(tasks, context: context(), hideCompleted: false)) == [
            ["Bugün teslim", "Açık", "Bitti"]
        ])
    let hidden = TaskViews.today(tasks, context: context(), hideCompleted: true)
    #expect(titles(hidden) == [["Bugün teslim", "Açık"]])
    #expect(hidden.hasTasks)
}

@Test("today: bölümler Rutinler, Geciken, Bugün teslim, Yaklaşan sırasındadır")
private func todaySectionOrder() {
    let tasks = [
        task("Yaklaşan", dueDate: "2026-11-21"),
        task("Gecikmiş", dueDate: "2026-11-17"),
        routine("Paragraf"),
        task("Bugün", dueDate: today),
    ]
    let result = TaskViews.today(tasks, context: context(), hideCompleted: false)
    #expect(result.sections.map(\.key) == ["routines", "overdue", "dueToday", "upcoming"])
    #expect(result.sections.map(\.id) == ["routines", "overdue", "dueToday", "upcoming"])
}

@Test("today: hepsi tamamlanıp gizlenince hasTasks true, bölüm yok")
private func todayAllHidden() {
    let result = TaskViews.today(
        [task("Bitti", dueDate: today, completedAt: local(2026, 11, 19, 7))],
        context: context(), hideCompleted: true)
    #expect(result.sections.isEmpty)
    #expect(result.hasTasks)
}

// MARK: - Satır modeli

@Test("row: rutin satırı — tamamlandı, seri, miktar (gerçekleşen/hedef), tekrar ve oran yalnızca ayrıntılı")
private func routineRow() {
    let paragraf = task(
        "Paragraf", kind: .routine, recurrence: daily, targetQuantity: 50, quantityUnit: "soru")
    let completions = [
        completion("Paragraf", day: "2026-11-18"), completion("Paragraf", quantity: 42),
    ]
    let simple = TaskViews.row(paragraf, context: context(completions: completions))
    #expect(simple.isDone)
    #expect(simple.canToggle)
    #expect(simple.streak == 2)
    #expect(simple.quantity == "42/50 soru")
    #expect(simple.recurrence == nil)
    #expect(simple.rate == nil)
    #expect(simple.due == nil)
    #expect(simple.id == paragraf.id)

    let detailed = TaskViews.row(paragraf, context: context(completions: completions), detailed: true)
    #expect(detailed.recurrence == "Her gün")
    #expect(detailed.rate == "Son 7 gün %29")
}

@Test("row: bugün planlı olmayan rutin işaretlenemez; seri yoksa nil; planlı gün yoksa oran nil")
private func unscheduledRoutineRow() {
    // 2026-11-19 Perşembe; yalnızca Pazartesi planlı.
    let monday = task("Pazartesi", kind: .routine, recurrence: RecurrenceRule(frequency: .weekly, weekdays: [1]))
    let row = TaskViews.row(monday, context: context(), detailed: true)
    #expect(!row.canToggle)
    #expect(!row.isDone)
    #expect(row.streak == nil)
    #expect(row.rate == "Son 7 gün %0")

    let future = TaskSnapshot(
        id: uuid("gelecek"), title: "Gelecek", kind: .routine, recurrence: daily,
        startDate: "2026-11-25", createdAt: local(2026, 11, 1))
    #expect(TaskViews.row(future, context: context(), detailed: true).rate == nil)
}

@Test("row: ödev satırı — ders adı, son tarih metni, gecikme, gerçekleşen miktar")
private func assignmentRow() {
    let subject = uuid("Fizik")
    let overdue = task(
        "Föy", dueDate: "2026-11-16", subjectId: subject, targetQuantity: 30,
        quantityUnit: " soru ", completedQuantity: nil)
    let ctx = context(subjectNames: [subject: "Fizik"])
    let row = TaskViews.row(overdue, context: ctx)
    #expect(row.subjectName == "Fizik")
    #expect(row.due == TaskViews.RowModel.Due(text: "3 gün gecikti", isOverdue: true))
    #expect(row.quantity == "30 soru")
    #expect(row.canToggle)
    #expect(row.streak == nil)

    let done = task("Bitti", dueDate: "2026-11-25", completedAt: local(2026, 11, 18), targetQuantity: 10, completedQuantity: 8)
    let doneRow = TaskViews.row(done, context: ctx)
    #expect(doneRow.isDone)
    #expect(doneRow.quantity == "8/10")
    #expect(doneRow.due == TaskViews.RowModel.Due(text: "6 gün kaldı", isOverdue: false))
    #expect(TaskViews.row(task("Tarihsiz"), context: ctx).due == nil)
    // Bilinmeyen ders id'si → ders adı yok.
    #expect(TaskViews.row(task("Başka", subjectId: uuid("Yok")), context: ctx).subjectName == nil)
}

// MARK: - Özet

@Test("summary: rutin + geciken + bugün teslim sayılır; yaklaşan sayılmaz")
private func summaryCounts() {
    let tasks = [
        routine("Paragraf"),
        routine("Kitap okuma"),
        task("Gecikmiş", dueDate: "2026-11-17"),
        task("Bugün", dueDate: today, completedAt: local(2026, 11, 19, 7)),
        task("Yaklaşan", dueDate: "2026-11-21"),
    ]
    let summary = TaskViews.summary(
        tasks, context: context(completions: [completion("Paragraf")]))
    #expect(summary == TaskViews.Summary(done: 2, total: 4))
    #expect(summary.progress == 0.5)
    #expect(!summary.isComplete)
}

@Test("summary: görev yok → ilerleme 0, tamamlanmış değil; hepsi bitince tamamlanmış")
private func summaryEdgeCases() {
    let empty = TaskViews.summary([], context: context())
    #expect(empty == TaskViews.Summary(done: 0, total: 0))
    #expect(empty.progress == 0)
    #expect(!empty.isComplete)

    let all = TaskViews.summary(
        [routine("Paragraf")], context: context(completions: [completion("Paragraf")]))
    #expect(all.isComplete)
    #expect(all.progress == 1)
}
