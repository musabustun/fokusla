import Foundation
import Testing

@testable import FokusDomain

// Görev hesapları testleri — web `web/src/domain/calc/tasks.test.ts` ile birebir aynı vakalar
// (aynı adlar, aynı girdi/çıktı değerleri). Web testleri süreç saat dilimini kullanır; burada
// `Calendar` Europe/Istanbul'a sabitlenip her çağrıya verilir. Web dize id'leri (`'r'`) deterministik
// UUID v5'e çevrilir.

// MARK: - Yardımcılar

/// Referans gün: 2026-11-19 Perşembe (ISO hafta günü 4).
private let today = "2026-11-19"

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private let testNamespace = UUID(uuidString: "9d3b6a52-1c1e-4f47-8a55-0b7d3a2f9c11")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

/// ISO dizgesini `Date`'e çevirir (UTC, milisaniyeli).
private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso)!
}

private let deletedAt = at("2026-11-20T00:00:00.000Z")

/// YEREL saatle bir an üretir; anın yerel günü (y, m, d) olur.
private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

private let daily = RecurrenceRule(frequency: .daily)

private func weekly(_ weekdays: Int...) -> RecurrenceRule {
    RecurrenceRule(frequency: .weekly, weekdays: weekdays)
}

private let idCounter = Counter()

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

private func makeTask(
    id: String? = nil, title: String = "Görev", kind: TaskKind = .routine, order: Int = 0,
    dueDate: ISODate? = nil, recurrence: RecurrenceRule? = daily, completedAt: Date? = nil,
    startDate: ISODate? = nil, createdAt: Date = local(2026, 11, 1), deletedAt: Date? = nil
) -> TaskSnapshot {
    TaskSnapshot(
        id: uuid(id ?? "task-\(idCounter.next())"), title: title, kind: kind, order: order,
        dueDate: dueDate, recurrence: recurrence, completedAt: completedAt, startDate: startDate,
        createdAt: createdAt, deletedAt: deletedAt)
}

private func makeAssignment(
    id: String? = nil, title: String = "Görev", order: Int = 0, dueDate: ISODate? = nil,
    completedAt: Date? = nil, startDate: ISODate? = nil, createdAt: Date = local(2026, 11, 1),
    deletedAt: Date? = nil, recurrence: RecurrenceRule? = nil
) -> TaskSnapshot {
    makeTask(
        id: id, title: title, kind: .assignment, order: order, dueDate: dueDate,
        recurrence: recurrence, completedAt: completedAt, startDate: startDate,
        createdAt: createdAt, deletedAt: deletedAt)
}

private func makeCompletion(
    taskId: String = "routine", date: ISODate = today, completedAt: Date? = nil,
    deletedAt: Date? = nil
) -> TaskCompletionSnapshot {
    let parts = date.split(separator: "-").map { Int($0)! }
    let moment = local(parts[0], parts[1], parts[2])
    return TaskCompletionSnapshot(
        id: uuid("completion-\(idCounter.next())"), taskId: uuid(taskId), date: date,
        completedAt: completedAt ?? moment, deletedAt: deletedAt)
}

/// Bir rutin için verilen günlerin tamamlamaları.
private func completions(on taskId: String, _ days: [ISODate]) -> [TaskCompletionSnapshot] {
    days.map { makeCompletion(taskId: taskId, date: $0) }
}

private func titles(_ tasks: [TaskSnapshot]) -> [String] { tasks.map(\.title) }

/// Test görünen adı olarak vaka adını kullanan vaka.
private struct Case<Input: Sendable, Expected: Sendable>: CustomTestStringConvertible, Sendable {
    let name: String
    let input: Input
    let expected: Expected
    var testDescription: String { name }
}

private func make<Input: Sendable, Expected: Sendable>(
    _ name: String, _ input: Input, _ expected: Expected
) -> Case<Input, Expected> {
    Case(name: name, input: input, expected: expected)
}

// MARK: - Gün aritmetiği

private let weekdayCases: [Case<ISODate, Int>] = [
    make("Pazartesi", "2026-11-16", 1),
    make("Salı", "2026-11-17", 2),
    make("Çarşamba", "2026-11-18", 3),
    make("Perşembe (referans gün)", "2026-11-19", 4),
    make("Cuma", "2026-11-20", 5),
    make("Cumartesi", "2026-11-21", 6),
    make("Pazar → 7 (Gregoryen 1 değil)", "2026-11-22", 7),
    make("artık gün 2028-02-29 Salı", "2028-02-29", 2),
    make("yılbaşı 2027-01-01 Cuma", "2027-01-01", 5),
    make("epoch öncesi 1969-12-31 Çarşamba", "1969-12-31", 3),
    make("epoch 1970-01-01 Perşembe", "1970-01-01", 4),
]

@Test("weekday(of:)", arguments: weekdayCases)
private func weekdayOf(_ testCase: Case<ISODate, Int>) {
    #expect(TasksCalc.weekday(of: testCase.input) == testCase.expected)
}

private let addDaysCases: [Case<(ISODate, Int), ISODate>] = [
    make("sıfır gün", ("2026-11-19", 0), "2026-11-19"),
    make("bir gün ileri", ("2026-11-19", 1), "2026-11-20"),
    make("bir gün geri", ("2026-11-19", -1), "2026-11-18"),
    make("ay sonu → ay başı", ("2026-11-30", 1), "2026-12-01"),
    make("ay başı → önceki ay sonu", ("2026-12-01", -1), "2026-11-30"),
    make("yıl sonu → yılbaşı", ("2026-12-31", 1), "2027-01-01"),
    make("yılbaşı → yıl sonu", ("2027-01-01", -1), "2026-12-31"),
    make("artık yıl 28 Şub → 29 Şub", ("2028-02-28", 1), "2028-02-29"),
    make("artık yıl 29 Şub → 1 Mart", ("2028-02-29", 1), "2028-03-01"),
    make("artık olmayan yıl 28 Şub → 1 Mart", ("2027-02-28", 1), "2027-03-01"),
    make("Pazar → Pazartesi (hafta devri)", ("2026-11-22", 1), "2026-11-23"),
    make("yaz saati geçişi (Mart) etkisiz", ("2027-03-27", 2), "2027-03-29"),
    make("büyük ileri atlama (365)", ("2027-01-01", 365), "2028-01-01"),
    make("artık yılda 366 gün", ("2028-01-01", 366), "2029-01-01"),
    make("epoch öncesine geri gitme", ("1970-01-01", -1), "1969-12-31"),
    make("yüzyıl artık yılı değil (2100-02-28 + 1)", ("2100-02-28", 1), "2100-03-01"),
    make("400 yıl artık yılı (2000-02-28 + 1)", ("2000-02-28", 1), "2000-02-29"),
]

@Test("addDays", arguments: addDaysCases)
private func addDays(_ testCase: Case<(ISODate, Int), ISODate>) {
    let (day, amount) = testCase.input
    #expect(TasksCalc.addDays(day, amount) == testCase.expected)
}

private let daysBetweenCases: [Case<(ISODate, ISODate), Int>] = [
    make("aynı gün", ("2026-11-19", "2026-11-19"), 0),
    make("ertesi gün", ("2026-11-19", "2026-11-20"), 1),
    make("önceki gün (negatif)", ("2026-11-19", "2026-11-18"), -1),
    make("yıl devri", ("2026-12-31", "2027-01-01"), 1),
    make("artık yıl Şubat", ("2028-02-28", "2028-03-01"), 2),
    make("artık olmayan yıl Şubat", ("2027-02-28", "2027-03-01"), 1),
    make("yaz saati geçişi (Ekim) tam gün", ("2026-10-24", "2026-10-26"), 2),
]

@Test("daysBetween", arguments: daysBetweenCases)
private func daysBetween(_ testCase: Case<(ISODate, ISODate), Int>) {
    let (from, to) = testCase.input
    #expect(TasksCalc.daysBetween(from: from, to: to) == testCase.expected)
}

@Test("addDays/daysBetween: geçersiz ISODate girdisi çökmez (sonuç tanımsız, epoch'a düşer)")
private func malformedISODateDoesNotCrash() {
    #expect(TasksCalc.daysBetween(from: "bozuk", to: "1970-01-01") == 0)
    #expect(TasksCalc.daysBetween(from: "", to: "1970-01-01") == 0)
    #expect(TasksCalc.addDays("2026", 0) == "2026-01-01")
    #expect(TasksCalc.addDays("2026-03", 0) == "2026-03-01")
}

// MARK: - Tekrar kuralı ve planlama

private let isDueCases: [Case<(RecurrenceRule, ISODate), Bool>] = [
    make("daily her gün (Perşembe)", (daily, "2026-11-19"), true),
    make("daily her gün (Pazar)", (daily, "2026-11-22"), true),
    make("weekly Pzt-Çar-Cum, Çarşamba", (weekly(1, 3, 5), "2026-11-18"), true),
    make("weekly Pzt-Çar-Cum, Perşembe", (weekly(1, 3, 5), "2026-11-19"), false),
    make("weekly Pazar, Pazar", (weekly(7), "2026-11-22"), true),
    make("weekly Pazar, sonraki Pazartesi", (weekly(7), "2026-11-23"), false),
    make("weekly Pazartesi, sonraki hafta", (weekly(1), "2026-11-30"), true),
    make("weekly boş weekdays → hiçbir gün", (RecurrenceRule(frequency: .weekly), "2026-11-19"), false),
]

@Test("isDue(on:)", arguments: isDueCases)
private func isDue(_ testCase: Case<(RecurrenceRule, ISODate), Bool>) {
    let (rule, day) = testCase.input
    #expect(TasksCalc.isDue(rule, on: day) == testCase.expected)
}

@Test("isDue(on:): bilinmeyen sıklık (ileride eklenen) hiçbir gün değildir")
private func isDueUnknownFrequency() {
    var rule = RecurrenceRule(frequency: .daily)
    rule.frequency = "monthly"
    #expect(TasksCalc.isDue(rule, on: today) == false)
}

private let routineStartDateCases: [Case<TaskSnapshot, ISODate>] = [
    make("startDate yok → createdAt yerel günü", makeTask(createdAt: local(2026, 11, 10)), "2026-11-10"),
    make(
        "startDate nil → createdAt yerel günü",
        makeTask(startDate: nil, createdAt: local(2026, 11, 10)), "2026-11-10"),
    make(
        "createdAt yerel 23:59 → aynı gün", makeTask(createdAt: local(2026, 11, 10, 23, 59)),
        "2026-11-10"),
    make(
        "createdAt yerel 00:00 → o gün", makeTask(createdAt: local(2026, 11, 11, 0, 0)),
        "2026-11-11"),
    make(
        "startDate createdAt'ten önce → startDate",
        makeTask(startDate: "2026-11-01", createdAt: local(2026, 11, 10)), "2026-11-01"),
    make(
        "startDate createdAt'ten sonra → startDate",
        makeTask(startDate: "2026-11-15", createdAt: local(2026, 11, 10)), "2026-11-15"),
]

@Test("routineStartDate", arguments: routineStartDateCases)
private func routineStartDate(_ testCase: Case<TaskSnapshot, ISODate>) {
    #expect(TasksCalc.routineStartDate(testCase.input, calendar: calendar) == testCase.expected)
}

private let isScheduledCases: [Case<(TaskSnapshot, ISODate), Bool>] = [
    make("günlük rutin, başlangıçtan sonra", (makeTask(), today), true),
    make(
        "günlük rutin, tam başlangıç günü",
        (makeTask(createdAt: local(2026, 11, 19, 23, 59)), today), true),
    make(
        "oluşturulmadan önceki gün planlı değil",
        (makeTask(createdAt: local(2026, 11, 19, 0, 0)), "2026-11-18"), false),
    make("startDate'ten önceki gün planlı değil", (makeTask(startDate: "2026-11-20"), today), false),
    make(
        "startDate oluşturmadan önce: geriye dönük planlı",
        (makeTask(startDate: "2026-11-10", createdAt: local(2026, 11, 19)), "2026-11-12"), true),
    make("haftalık, gün eşleşiyor", (makeTask(recurrence: weekly(4)), today), true),
    make("haftalık, gün eşleşmiyor", (makeTask(recurrence: weekly(1)), today), false),
    make(
        "haftalık boş weekdays",
        (makeTask(recurrence: RecurrenceRule(frequency: .weekly)), today), false),
    make("recurrence nil", (makeTask(recurrence: nil), today), false),
    make("silinmiş rutin", (makeTask(deletedAt: deletedAt), today), false),
    make(
        "ödev hiçbir zaman planlı değil",
        (makeAssignment(dueDate: today, recurrence: daily), today), false),
]

@Test("isScheduled(on:)", arguments: isScheduledCases)
private func isScheduled(_ testCase: Case<(TaskSnapshot, ISODate), Bool>) {
    let (task, day) = testCase.input
    #expect(TasksCalc.isScheduled(task, on: day, calendar: calendar) == testCase.expected)
}

// MARK: - Tamamlama

private let assignmentCompletionDayCases: [Case<TaskSnapshot, ISODate?>] = [
    make("tamamlanmamış ödev", makeAssignment(), nil),
    make(
        "yerel 23:59 tamamlandı → aynı gün",
        makeAssignment(completedAt: local(2026, 11, 19, 23, 59)), "2026-11-19"),
    make(
        "yerel 00:00 tamamlandı → yeni gün",
        makeAssignment(completedAt: local(2026, 11, 20, 0, 0)), "2026-11-20"),
    make(
        "rutin (completedAt dolu olsa bile) → nil", makeTask(completedAt: local(2026, 11, 19)),
        nil),
]

@Test("assignmentCompletionDay", arguments: assignmentCompletionDayCases)
private func assignmentCompletionDay(_ testCase: Case<TaskSnapshot, ISODate?>) {
    #expect(
        TasksCalc.assignmentCompletionDay(testCase.input, calendar: calendar) == testCase.expected)
}

private struct FindCompletionCase: CustomTestStringConvertible, Sendable {
    let name: String
    let completions: [TaskCompletionSnapshot]
    let expected: TaskCompletionSnapshot?
    var testDescription: String { name }
}

private let findCompletionCases: [FindCompletionCase] = {
    let early = makeCompletion(taskId: "r", date: today, completedAt: local(2026, 11, 19, 8))
    let late = makeCompletion(taskId: "r", date: today, completedAt: local(2026, 11, 19, 20))
    let deletedEarliest = makeCompletion(
        taskId: "r", date: today, completedAt: local(2026, 11, 19, 6), deletedAt: deletedAt)
    let otherTask = makeCompletion(taskId: "x", date: today)
    let otherDay = makeCompletion(taskId: "r", date: "2026-11-18")
    return [
        FindCompletionCase(name: "boş liste", completions: [], expected: nil),
        FindCompletionCase(name: "tek eşleşme", completions: [late], expected: late),
        FindCompletionCase(
            name: "kopyalar → en erken completedAt", completions: [late, early], expected: early),
        FindCompletionCase(
            name: "kopyalar (ters sıra) → en erken", completions: [early, late], expected: early),
        FindCompletionCase(
            name: "silinmiş (daha erken) tamamlama yok sayılır",
            completions: [deletedEarliest, late], expected: late),
        FindCompletionCase(
            name: "yalnızca silinmiş → yok", completions: [deletedEarliest], expected: nil),
        FindCompletionCase(
            name: "başka görev / başka gün → yok", completions: [otherTask, otherDay], expected: nil),
    ]
}()

@Test("findCompletion", arguments: findCompletionCases)
private func findCompletion(_ testCase: FindCompletionCase) {
    #expect(
        TasksCalc.findCompletion(testCase.completions, taskId: uuid("r"), day: today)
            == testCase.expected)
}

private struct IsCompletedCase: CustomTestStringConvertible, Sendable {
    let name: String
    let task: TaskSnapshot
    let completions: [TaskCompletionSnapshot]
    let day: ISODate
    let expected: Bool
    var testDescription: String { name }
}

private let isCompletedCases: [IsCompletedCase] = {
    let routine = makeTask(id: "r")
    let done = makeCompletion(taskId: "r", date: today)
    let deletedDone = makeCompletion(taskId: "r", date: today, deletedAt: deletedAt)
    func entry(
        _ name: String, _ task: TaskSnapshot, _ completions: [TaskCompletionSnapshot],
        day: ISODate = today, _ expected: Bool
    ) -> IsCompletedCase {
        IsCompletedCase(name: name, task: task, completions: completions, day: day, expected: expected)
    }
    return [
        entry("rutin, o gün tamamlanmış", routine, [done], true),
        entry("rutin, tamamlama yok", routine, [], false),
        entry("rutin, başka günün tamamlaması", routine, [done], day: "2026-11-18", false),
        entry("rutin, yalnızca silinmiş tamamlama", routine, [deletedDone], false),
        entry(
            "rutin, kopya tamamlamalar", routine, [done, makeCompletion(taskId: "r", date: today)],
            true),
        entry("silinmiş rutin", makeTask(id: "r", deletedAt: deletedAt), [done], false),
        entry("ödev, açık", makeAssignment(), [], false),
        entry(
            "ödev, aynı gün (23:59) tamamlandı",
            makeAssignment(completedAt: local(2026, 11, 19, 23, 59)), [], true),
        entry(
            "ödev, önceki gün tamamlandı", makeAssignment(completedAt: local(2026, 11, 18)), [],
            true),
        entry(
            "ödev, ertesi gün 00:00 tamamlandı → o gün için değil",
            makeAssignment(completedAt: local(2026, 11, 20, 0, 0)), [], false),
        entry(
            "silinmiş ödev",
            makeAssignment(completedAt: local(2026, 11, 18), deletedAt: deletedAt), [], false),
    ]
}()

@Test("isCompleted(on:)", arguments: isCompletedCases)
private func isCompleted(_ testCase: IsCompletedCase) {
    #expect(
        TasksCalc.isCompleted(
            testCase.task, completions: testCase.completions, on: testCase.day, calendar: calendar)
            == testCase.expected)
}

// MARK: - Ödev son tarihleri

private let isOverdueCases: [Case<TaskSnapshot, Bool>] = [
    make("dün son tarihli, açık", makeAssignment(dueDate: "2026-11-18"), true),
    make("bugün son tarihli", makeAssignment(dueDate: today), false),
    make("yarın son tarihli", makeAssignment(dueDate: "2026-11-20"), false),
    make("son tarih yok", makeAssignment(dueDate: nil), false),
    make(
        "dün son tarihli ama tamamlanmış",
        makeAssignment(dueDate: "2026-11-18", completedAt: local(2026, 11, 19)), false),
    make("silinmiş", makeAssignment(dueDate: "2026-11-18", deletedAt: deletedAt), false),
    make("rutin (dueDate olsa bile)", makeTask(dueDate: "2026-11-18"), false),
]

@Test("isOverdue", arguments: isOverdueCases)
private func isOverdue(_ testCase: Case<TaskSnapshot, Bool>) {
    #expect(TasksCalc.isOverdue(testCase.input, today: today) == testCase.expected)
}

@Test("overdueAssignments: yalnızca gecikenleri döner; en eski son tarih önce, eşitlikte order sonra title (tr-TR)")
private func overdueAssignmentsOrdering() {
    let tasks = [
        makeAssignment(title: "Dün B", order: 1, dueDate: "2026-11-18"),
        makeAssignment(title: "Geçen hafta", order: 5, dueDate: "2026-11-12"),
        makeAssignment(title: "Dün A", order: 1, dueDate: "2026-11-18"),
        makeAssignment(title: "Dün sıra 0", order: 0, dueDate: "2026-11-18"),
        makeAssignment(title: "İngilizce", dueDate: "2026-11-17"),
        makeAssignment(title: "Isı", dueDate: "2026-11-17"),
        makeAssignment(title: "Bugün", dueDate: today),
        makeAssignment(title: "Bitti", dueDate: "2026-11-10", completedAt: local(2026, 11, 11)),
        makeAssignment(title: "Silindi", dueDate: "2026-11-10", deletedAt: deletedAt),
        makeTask(title: "Rutin"),
    ]
    let input = tasks

    let result = TasksCalc.overdueAssignments(tasks, today: today)

    // tr-TR: "I" < "İ" (Türk alfabesi: ... H, I, İ, J ...)
    #expect(
        titles(result) == ["Geçen hafta", "Isı", "İngilizce", "Dün sıra 0", "Dün A", "Dün B"])
    #expect(tasks == input)  // girdi değişmez
}

@Test("overdueAssignments: boş liste → boş")
private func overdueAssignmentsEmpty() {
    #expect(TasksCalc.overdueAssignments([], today: today).isEmpty)
}

@Test("overdueAssignments: tam eşit görevlerde girdi sırası korunur (kararlı sıralama)")
private func overdueAssignmentsStable() {
    let first = makeAssignment(id: "ilk", title: "Aynı", dueDate: "2026-11-18")
    let second = makeAssignment(id: "ikinci", title: "Aynı", dueDate: "2026-11-18")
    #expect(TasksCalc.overdueAssignments([first, second], today: today).map(\.id) == [first.id, second.id])
    #expect(TasksCalc.overdueAssignments([second, first], today: today).map(\.id) == [second.id, first.id])
}

private let daysUntilDueCases: [Case<TaskSnapshot, Int?>] = [
    make("bugün → 0", makeAssignment(dueDate: today), 0),
    make("yarın → 1", makeAssignment(dueDate: "2026-11-20"), 1),
    make("dün → -1", makeAssignment(dueDate: "2026-11-18"), -1),
    make("ay devri", makeAssignment(dueDate: "2026-12-01"), 12),
    make("son tarih yok → nil", makeAssignment(dueDate: nil), nil),
    make("rutin → nil", makeTask(dueDate: today), nil),
]

@Test("daysUntilDue", arguments: daysUntilDueCases)
private func daysUntilDue(_ testCase: Case<TaskSnapshot, Int?>) {
    #expect(TasksCalc.daysUntilDue(testCase.input, today: today) == testCase.expected)
}

// MARK: - Gündem

private enum Group: String, Sendable {
    case routines, overdue, dueToday, upcoming, none
}

private let agendaGroupCases: [Case<TaskSnapshot, Group>] = [
    // Rutinler
    make("günlük rutin", makeTask(), .routines),
    make("haftalık rutin, bugün değil", makeTask(recurrence: weekly(1)), .none),
    make("rutin, başlangıçtan önce", makeTask(startDate: "2026-11-20"), .none),
    make("silinmiş rutin", makeTask(deletedAt: deletedAt), .none),
    // Açık ödevler — aralık
    make("açık, dün son tarihli", makeAssignment(dueDate: "2026-11-18"), .overdue),
    make("açık, çok eski son tarih", makeAssignment(dueDate: "2025-01-01"), .overdue),
    make("açık, bugün son tarihli", makeAssignment(dueDate: today), .dueToday),
    make("açık, son tarih yok", makeAssignment(dueDate: nil), .dueToday),
    make("açık, yarın", makeAssignment(dueDate: "2026-11-20"), .upcoming),
    make("ufuk sınırı: tam gün+7 dahil", makeAssignment(dueDate: "2026-11-26"), .upcoming),
    make("ufuk sınırı: gün+8 hariç", makeAssignment(dueDate: "2026-11-27"), .none),
    // Tamamlanma günü
    make(
        "bugün (23:59) tamamlanan, bugün son tarihli → listede kalır",
        makeAssignment(dueDate: today, completedAt: local(2026, 11, 19, 23, 59)), .dueToday),
    make(
        "bugün tamamlanan, geciken → listede kalır",
        makeAssignment(dueDate: "2026-11-15", completedAt: local(2026, 11, 19)), .overdue),
    make(
        "bugün tamamlanan, yaklaşan → listede kalır",
        makeAssignment(dueDate: "2026-11-22", completedAt: local(2026, 11, 19)), .upcoming),
    make(
        "bugün tamamlanan ama ufuk dışı → hariç",
        makeAssignment(dueDate: "2026-12-31", completedAt: local(2026, 11, 19)), .none),
    make(
        "dün (23:59) tamamlanan → hariç",
        makeAssignment(dueDate: today, completedAt: local(2026, 11, 18, 23, 59)), .none),
    make(
        "tarihsiz, önceki gün tamamlanan → hariç",
        makeAssignment(dueDate: nil, completedAt: local(2026, 11, 10)), .none),
    make(
        "sonraki gün (00:00) tamamlanan → o gün açıktı, dahil",
        makeAssignment(dueDate: today, completedAt: local(2026, 11, 20, 0, 0)), .dueToday),
    make("silinmiş açık ödev", makeAssignment(dueDate: today, deletedAt: deletedAt), .none),
]

@Test("agenda(for:): görev doğru gruba girer", arguments: agendaGroupCases)
private func agendaGroups(_ testCase: Case<TaskSnapshot, Group>) {
    let task = testCase.input
    let agenda = TasksCalc.agenda(for: today, tasks: [task], calendar: calendar)
    let groups: [(Group, [TaskSnapshot])] = [
        (.routines, agenda.routines), (.overdue, agenda.overdue),
        (.dueToday, agenda.dueToday), (.upcoming, agenda.upcoming),
    ]
    let found = groups.filter { $0.1.contains(task) }.map(\.0)
    #expect(found == (testCase.expected == .none ? [] : [testCase.expected]))
}

@Test("agenda(for:): her grubu kendi içinde sıralar")
private func agendaSorting() {
    let tasks = [
        makeTask(title: "Rutin B", order: 1),
        makeTask(title: "Rutin A", order: 1),
        makeTask(title: "Rutin sıra 0", order: 0),
        makeAssignment(title: "Gecikmiş yeni", dueDate: "2026-11-18"),
        makeAssignment(title: "Gecikmiş eski", order: 9, dueDate: "2026-11-10"),
        makeAssignment(title: "Tarihsiz sıra 0", order: 0, dueDate: nil),
        makeAssignment(title: "Bugün sıra 2", order: 2, dueDate: today),
        makeAssignment(title: "Tarihsiz sıra 1", order: 1, dueDate: nil),
        makeAssignment(title: "Bugün sıra 1", order: 1, dueDate: today),
        makeAssignment(title: "Yaklaşan uzak", dueDate: "2026-11-25"),
        makeAssignment(title: "Yaklaşan yakın", order: 3, dueDate: "2026-11-20"),
    ]

    let agenda = TasksCalc.agenda(for: today, tasks: tasks, calendar: calendar)

    #expect(titles(agenda.routines) == ["Rutin sıra 0", "Rutin A", "Rutin B"])
    #expect(titles(agenda.overdue) == ["Gecikmiş eski", "Gecikmiş yeni"])
    // Önce son tarihi bugün olanlar, sonra tarihsizler (her biri order/title).
    #expect(
        titles(agenda.dueToday) == [
            "Bugün sıra 1", "Bugün sıra 2", "Tarihsiz sıra 0", "Tarihsiz sıra 1",
        ])
    #expect(titles(agenda.upcoming) == ["Yaklaşan yakın", "Yaklaşan uzak"])
}

@Test("agenda(for:): tarihsiz ödev, tarihliden sonra gelir (girdi sırasından bağımsız)")
private func agendaUndatedAfterDated() {
    let dated = makeAssignment(title: "Tarihli", dueDate: today)
    let undated = makeAssignment(title: "Tarihsiz", dueDate: nil)
    for input in [[dated, undated], [undated, dated]] {
        let agenda = TasksCalc.agenda(for: today, tasks: input, calendar: calendar)
        #expect(titles(agenda.dueToday) == ["Tarihli", "Tarihsiz"])
    }
}

private let horizonCases: [Case<(Int?, ISODate), Bool>] = [
    make("varsayılan ufuk (7): gün+7 dahil", (nil, "2026-11-26"), true),
    make("varsayılan ufuk (7): gün+8 hariç", (nil, "2026-11-27"), false),
    make("ufuk 0: yarın hariç", (0, "2026-11-20"), false),
    make("ufuk 14: gün+14 dahil (ay devri)", (14, "2026-12-03"), true),
]

@Test("agenda(for:): ufuk", arguments: horizonCases)
private func agendaHorizon(_ testCase: Case<(Int?, ISODate), Bool>) {
    let (horizonDays, dueDate) = testCase.input
    let task = makeAssignment(dueDate: dueDate)
    let agenda = horizonDays.map {
        TasksCalc.agenda(for: today, tasks: [task], horizonDays: $0, calendar: calendar)
    } ?? TasksCalc.agenda(for: today, tasks: [task], calendar: calendar)
    #expect(agenda.upcoming.contains(task) == testCase.expected)
}

@Test("varsayılan ufuk upcomingHorizonDays = 7")
private func upcomingHorizonConstant() {
    #expect(TasksCalc.upcomingHorizonDays == 7)
}

@Test("agenda(for:): boş liste → boş gruplar")
private func agendaEmpty() {
    #expect(
        TasksCalc.agenda(for: today, tasks: [], calendar: calendar)
            == TasksCalc.DayAgenda(routines: [], overdue: [], dueToday: [], upcoming: []))
}

@Test("tasks(for:in:): rutinler, gecikenler, bugünkü ve yaklaşan ödevler sırasıyla birleşir")
private func tasksForDay() {
    let tasks = [
        makeAssignment(title: "Yaklaşan", dueDate: "2026-11-21"),
        makeAssignment(title: "Bugün", dueDate: today),
        makeAssignment(title: "Gecikmiş", dueDate: "2026-11-17"),
        makeTask(title: "Rutin"),
        makeAssignment(title: "Ufuk dışı", dueDate: "2026-12-31"),
        makeAssignment(title: "Silinmiş", dueDate: today, deletedAt: deletedAt),
    ]
    #expect(
        titles(TasksCalc.tasks(for: today, in: tasks, calendar: calendar))
            == ["Rutin", "Gecikmiş", "Bugün", "Yaklaşan"])
}

// MARK: - Seri ve oran

private struct StreakCase: CustomTestStringConvertible, Sendable {
    let name: String
    let task: TaskSnapshot
    let done: [ISODate]
    let extra: [TaskCompletionSnapshot]
    let expected: Int
    var testDescription: String { name }
}

private let streakCases: [StreakCase] = {
    // Varsayılan rutin 2026-11-01'de oluşturuldu (günlük).
    func entry(
        _ name: String, _ task: TaskSnapshot, done: [ISODate], extra: [TaskCompletionSnapshot] = [],
        _ expected: Int
    ) -> StreakCase {
        StreakCase(name: name, task: task, done: done, extra: extra, expected: expected)
    }
    return [
        entry("hiç tamamlama yok", makeTask(id: "r"), done: [], 0),
        entry(
            "bugün dahil 3 gün üst üste", makeTask(id: "r"),
            done: ["2026-11-17", "2026-11-18", "2026-11-19"], 3),
        entry(
            "bugün henüz yapılmadı → seri bozulmaz, dünden sayılır", makeTask(id: "r"),
            done: ["2026-11-17", "2026-11-18"], 2),
        entry(
            "dün kaçırıldı → seri yalnızca bugün", makeTask(id: "r"),
            done: ["2026-11-16", "2026-11-17", "2026-11-19"], 1),
        entry(
            "bugün ve dün yapılmadı → 0", makeTask(id: "r"), done: ["2026-11-16", "2026-11-17"], 0),
        entry(
            "başlangıç gününde durur (öncesine bakılmaz)",
            makeTask(id: "r", createdAt: local(2026, 11, 17, 23, 59)),
            done: ["2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19"], 3),
        entry(
            "startDate öncesi tamamlamalar sayılmaz", makeTask(id: "r", startDate: "2026-11-18"),
            done: ["2026-11-17", "2026-11-18", "2026-11-19"], 2),
        entry(
            "başlangıç bugünden sonra → 0", makeTask(id: "r", startDate: "2026-11-20"),
            done: ["2026-11-19"], 0),
        entry(
            "haftalık Pzt-Çar-Cum: planlı olmayan günlerdeki boşluklar seriyi bozmaz",
            // Bugün Perşembe (planlı değil). Çar 18, Pzt 16, Cum 13, Çar 11 yapıldı; Pzt 9 kaçırıldı.
            makeTask(id: "r", recurrence: weekly(1, 3, 5)),
            done: ["2026-11-11", "2026-11-13", "2026-11-16", "2026-11-18"], 4),
        entry(
            "haftalık Pazar: hafta devri boyunca (Pazar → Pazartesi) sayılır",
            makeTask(id: "r", recurrence: weekly(7)), done: ["2026-11-08", "2026-11-15"], 2),
        entry(
            "haftalık Perşembe: bugün planlı ama yapılmadı → geçen haftadan sayılır",
            makeTask(id: "r", recurrence: weekly(4)), done: ["2026-11-05", "2026-11-12"], 2),
        entry(
            "planlı olmayan günde tamamlama seriye eklenmez",
            makeTask(id: "r", recurrence: weekly(3)), done: ["2026-11-17", "2026-11-18"], 1),
        entry(
            "haftalık boş weekdays → 0",
            makeTask(id: "r", recurrence: RecurrenceRule(frequency: .weekly)),
            done: ["2026-11-18", "2026-11-19"], 0),
        entry(
            "kopya tamamlamalar tek sayılır", makeTask(id: "r"),
            done: ["2026-11-18", "2026-11-18", "2026-11-19", "2026-11-19"], 2),
        entry(
            "silinmiş tamamlama seriyi kırar", makeTask(id: "r"),
            done: ["2026-11-17", "2026-11-19"],
            extra: [makeCompletion(taskId: "r", date: "2026-11-18", deletedAt: deletedAt)], 1),
        entry(
            "başka görevin tamamlaması sayılmaz", makeTask(id: "r"), done: [],
            extra: [makeCompletion(taskId: "x", date: today)], 0),
        entry(
            "ay devri boyunca seri", makeTask(id: "r", createdAt: local(2026, 10, 1)),
            done: ["2026-10-30", "2026-10-31", "2026-11-01"],
            0),  // 2026-11-02 … 19 kaçırıldı
        entry("silinmiş rutin → 0", makeTask(id: "r", deletedAt: deletedAt), done: ["2026-11-19"], 0),
        entry("recurrence nil → 0", makeTask(id: "r", recurrence: nil), done: ["2026-11-19"], 0),
        entry("ödev → 0", makeAssignment(id: "r"), done: ["2026-11-19"], 0),
    ]
}()

@Test("routineStreak", arguments: streakCases)
private func routineStreak(_ testCase: StreakCase) {
    let all = completions(on: "r", testCase.done) + testCase.extra
    #expect(
        TasksCalc.routineStreak(testCase.task, completions: all, today: today, calendar: calendar)
            == testCase.expected)
}

@Test("routineStreak: ay/yıl devri boyunca kesintisiz seri")
private func routineStreakAcrossYear() {
    let task = makeTask(id: "r", startDate: "2026-12-30")
    let done = ["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"]
    #expect(
        TasksCalc.routineStreak(
            task, completions: completions(on: "r", done), today: "2027-01-02", calendar: calendar)
            == 4)
}

private struct RateCase: CustomTestStringConvertible, Sendable {
    let name: String
    let task: TaskSnapshot
    let done: [ISODate]
    let extra: [TaskCompletionSnapshot]
    let windowDays: Int?
    let scheduled: Int
    let completed: Int
    let rate: Double?
    var testDescription: String { name }
}

private let rateCases: [RateCase] = {
    func entry(
        _ name: String, _ task: TaskSnapshot, done: [ISODate], extra: [TaskCompletionSnapshot] = [],
        windowDays: Int? = nil, scheduled: Int, completed: Int, rate: Double?
    ) -> RateCase {
        RateCase(
            name: name, task: task, done: done, extra: extra, windowDays: windowDays,
            scheduled: scheduled, completed: completed, rate: rate)
    }
    return [
        entry(
            "günlük, 7 günün 7'si", makeTask(id: "r"),
            done: [
                "2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18",
                "2026-11-19",
            ], scheduled: 7, completed: 7, rate: 1),
        entry("günlük, hiç tamamlama yok", makeTask(id: "r"), done: [], scheduled: 7, completed: 0, rate: 0),
        entry(
            "pencere dışı (today−7) tamamlama sayılmaz", makeTask(id: "r"),
            done: ["2026-11-12", "2026-11-19"], scheduled: 7, completed: 1, rate: 1.0 / 7),
        entry(
            "bugün planlı ve yapılmadı → paydada sayılır", makeTask(id: "r"),
            done: ["2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18"],
            scheduled: 7, completed: 6, rate: 6.0 / 7),
        entry(
            "başlangıçtan önceki günler hariç",
            makeTask(id: "r", createdAt: local(2026, 11, 17, 23, 59)),
            done: ["2026-11-15", "2026-11-17", "2026-11-19"], scheduled: 3, completed: 2,
            rate: 2.0 / 3),
        entry(
            "haftalık Pzt-Çar-Cum (pencere 13–19 Kasım)",
            makeTask(id: "r", recurrence: weekly(1, 3, 5)),
            done: ["2026-11-13", "2026-11-16", "2026-11-17"], scheduled: 3, completed: 2,
            rate: 2.0 / 3),
        entry(
            "kopya tamamlamalar tek sayılır", makeTask(id: "r"),
            done: ["2026-11-19", "2026-11-19", "2026-11-19"], scheduled: 7, completed: 1,
            rate: 1.0 / 7),
        entry(
            "silinmiş tamamlama sayılmaz", makeTask(id: "r"), done: [],
            extra: [makeCompletion(taskId: "r", date: today, deletedAt: deletedAt)], scheduled: 7,
            completed: 0, rate: 0),
        entry(
            "özel pencere 3 gün", makeTask(id: "r"), done: ["2026-11-16", "2026-11-18"],
            windowDays: 3, scheduled: 3, completed: 1, rate: 1.0 / 3),
        entry(
            "pencere 0 → planlı gün yok, oran nil", makeTask(id: "r"), done: ["2026-11-19"],
            windowDays: 0, scheduled: 0, completed: 0, rate: nil),
        entry(
            "negatif pencere → planlı gün yok, oran nil", makeTask(id: "r"), done: ["2026-11-19"],
            windowDays: -3, scheduled: 0, completed: 0, rate: nil),
        entry(
            "başlangıç bugünden sonra → oran nil", makeTask(id: "r", startDate: "2026-11-20"),
            done: [], scheduled: 0, completed: 0, rate: nil),
        entry(
            "haftalık boş weekdays → oran nil",
            makeTask(id: "r", recurrence: RecurrenceRule(frequency: .weekly)), done: ["2026-11-19"],
            scheduled: 0, completed: 0, rate: nil),
        entry(
            "silinmiş rutin → oran nil", makeTask(id: "r", deletedAt: deletedAt),
            done: ["2026-11-19"], scheduled: 0, completed: 0, rate: nil),
        entry(
            "ödev → oran nil", makeAssignment(id: "r"), done: ["2026-11-19"], scheduled: 0,
            completed: 0, rate: nil),
    ]
}()

@Test("completionRate", arguments: rateCases)
private func completionRate(_ testCase: RateCase) {
    let all = completions(on: "r", testCase.done) + testCase.extra
    let result = testCase.windowDays.map {
        TasksCalc.completionRate(
            testCase.task, completions: all, today: today, windowDays: $0, calendar: calendar)
    } ?? TasksCalc.completionRate(testCase.task, completions: all, today: today, calendar: calendar)
    #expect(result.scheduled == testCase.scheduled)
    #expect(result.completed == testCase.completed)
    if let expected = testCase.rate {
        #expect(abs((result.rate ?? .nan) - expected) < 1e-10)
    } else {
        #expect(result.rate == nil)
    }
}

@Test("varsayılan pencere completionRateWindowDays = 7")
private func completionRateWindowConstant() {
    #expect(TasksCalc.completionRateWindowDays == 7)
}
