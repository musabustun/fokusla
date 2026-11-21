import Foundation
import Testing

@testable import FokusDomain

// Görev taslağı testleri — web `web/src/features/tasks/taskModel.test.ts` içindeki `emptyDraft`,
// `parseQuantity` ve `validateDraft` vakalarıyla aynı girdi/çıktı değerleri (hata metinleri birebir).

private let today = "2026-11-19"
private let tomorrow = "2026-11-20"

private func draft(
    kind: TaskKind = .routine, title: String = "Paragraf", notes: String = "", subjectId: UUID? = nil,
    frequency: RecurrenceFrequency = .daily, weekdays: [Int] = [], dueDate: String = today,
    targetQuantity: String = "", quantityUnit: String = ""
) -> TaskDraft {
    TaskDraft(
        kind: kind, title: title, notes: notes, subjectId: subjectId, frequency: frequency,
        weekdays: weekdays, dueDate: dueDate, targetQuantity: targetQuantity,
        quantityUnit: quantityUnit)
}

private func validValues(_ result: TaskDraft.Validation) -> TaskValues? {
    if case let .valid(values) = result { return values }
    return nil
}

private func errors(_ result: TaskDraft.Validation) -> [TaskDraft.Field: String]? {
    if case let .invalid(errors) = result { return errors }
    return nil
}

// MARK: - empty

@Suite("emptyDraft")
struct TaskDraftEmptyTests {
    @Test("tür için boş taslak döner", arguments: TaskKind.allCases)
    func empty(kind: TaskKind) {
        let result = TaskDraft.empty(kind, today: today)
        #expect(result.kind == kind)
        #expect(result.title == "")
        #expect(result.notes == "")
        #expect(result.subjectId == nil)
        #expect(result.frequency == .daily)
        #expect(result.weekdays == [])
        #expect(result.dueDate == today)
        #expect(result.targetQuantity == "")
        #expect(result.quantityUnit == "")
        #expect(result == TaskDraft(kind: kind, dueDate: today))
    }
}

// MARK: - parseQuantity

@Suite("parseQuantity")
struct TaskDraftParseQuantityTests {
    @Test("girdi → sonuç", arguments: [
        ("", TaskDraft.ParsedQuantity.empty),
        ("   ", .empty),
        ("1", .value(1)),
        (" 42 ", .value(42)),
        ("10000", .value(10_000)),
        ("1.000", .value(1000)),
        ("10.000", .value(10_000)),
        ("0", .notPositiveInteger),
        ("-3", .notPositiveInteger),
        ("2.5", .notPositiveInteger),
        ("2,5", .notPositiveInteger),
        ("1e3", .notPositiveInteger),
        ("abc", .notPositiveInteger),
        ("10001", .tooLarge),
        ("10.001", .tooLarge),
        ("1.00", .notPositiveInteger),
        ("0.000", .notPositiveInteger),
        ("00", .notPositiveInteger),
        ("99999999999999999999999", .tooLarge),
    ])
    func table(input: String, expected: TaskDraft.ParsedQuantity) {
        #expect(TaskDraft.parseQuantity(input) == expected)
    }
}

// MARK: - yardımcılar

@Suite("TaskDraft yardımcıları")
struct TaskDraftHelperTests {
    @Test("normalizeWeekdays geçerli, tekil, sıralı döner", arguments: [
        ([5, 1, 5, 3], [1, 3, 5]),
        ([0, 8, -1, 7, 7], [7]),
        ([], []),
        ([9, 0], []),
    ])
    func normalize(input: [Int], expected: [Int]) {
        #expect(TaskDraft.normalizeWeekdays(input) == expected)
    }

    @Test("isValidISODate", arguments: [
        ("2026-11-19", true),
        ("2028-02-29", true),
        ("2026-02-30", false),
        ("2026-13-01", false),
        ("2026-00-10", false),
        ("2026-02-29", false),
        ("19.11.2026", false),
        ("2026-1-1", false),
        ("", false),
        ("x", false),
    ])
    func isoDate(value: String, expected: Bool) {
        #expect(TaskDraft.isValidISODate(value) == expected)
    }

    @Test("sınır sabitleri web ile aynı")
    func constants() {
        #expect(TaskDraft.titleMaxLength == 120)
        #expect(TaskDraft.notesMaxLength == 1000)
        #expect(TaskDraft.quantityMax == 10_000)
        #expect(TaskDraft.unitMaxLength == 24)
    }
}

// MARK: - validate

@Suite("validateDraft")
struct TaskDraftValidateTests {
    @Test("rutini normalize eder (trim, boş → nil, ödev alanları nil)")
    func normalizesRoutine() {
        let subject = UUID()
        let result = draft(
            title: "  Paragraf  ", notes: "   ", subjectId: subject, dueDate: today,
            targetQuantity: " 40 ", quantityUnit: " soru ").validate()
        #expect(result == .valid(TaskValues(
            kind: .routine, title: "Paragraf", notes: nil, subjectId: subject, dueDate: nil,
            recurrence: RecurrenceRule(frequency: .daily, weekdays: []), targetQuantity: 40,
            quantityUnit: "soru")))
    }

    @Test("daily rutinde seçili günleri yok sayar")
    func dailyIgnoresWeekdays() {
        let values = validValues(draft(frequency: .daily, weekdays: [1, 2]).validate())
        #expect(values?.recurrence == RecurrenceRule(frequency: .daily, weekdays: []))
    }

    @Test("weekly rutinde günleri sıralar ve tekilleştirir, girdiyi değiştirmez")
    func weeklySortsAndDedups() {
        let input = draft(frequency: .weekly, weekdays: [5, 1, 5, 3])
        let values = validValues(input.validate())
        #expect(values?.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [1, 3, 5]))
        #expect(input.weekdays == [5, 1, 5, 3])
    }

    @Test("weekly rutinde geçersiz günler elenir")
    func weeklyDropsInvalidDays() {
        let values = validValues(draft(frequency: .weekly, weekdays: [0, 3, 9]).validate())
        #expect(values?.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [3]))
    }

    @Test("ödevi normalize eder (recurrence nil, not korunur)")
    func normalizesAssignment() {
        var input = TaskDraft.empty(.assignment, today: today)
        input.title = "Deneme"
        input.notes = " Yanlışlar "
        input.frequency = .weekly
        input.weekdays = []
        input.dueDate = " \(tomorrow) "
        #expect(input.validate() == .valid(TaskValues(
            kind: .assignment, title: "Deneme", notes: "Yanlışlar", subjectId: nil,
            dueDate: tomorrow, recurrence: nil, targetQuantity: nil, quantityUnit: nil)))
    }

    @Test("sınır uzunluklarını kabul eder")
    func acceptsBoundaryLengths() {
        let result = draft(
            title: String(repeating: "a", count: TaskDraft.titleMaxLength),
            notes: String(repeating: "b", count: TaskDraft.notesMaxLength),
            targetQuantity: String(TaskDraft.quantityMax),
            quantityUnit: String(repeating: "c", count: TaskDraft.unitMaxLength)).validate()
        #expect(validValues(result) != nil)
    }

    @Test("miktar binlik ayraçla kabul edilir")
    func thousandsSeparator() {
        #expect(validValues(draft(targetQuantity: "1.000").validate())?.targetQuantity == 1000)
    }

    struct ErrorCase: Sendable, CustomTestStringConvertible {
        let name: String
        let draft: TaskDraft
        let errors: [TaskDraft.Field: String]
        var testDescription: String { name }
    }

    static let errorCases: [ErrorCase] = [
        .init(name: "boş başlık", draft: draft(title: "   "), errors: [.title: "Başlık gerekli"]),
        .init(
            name: "uzun başlık",
            draft: draft(title: String(repeating: "a", count: TaskDraft.titleMaxLength + 1)),
            errors: [.title: "Başlık en fazla 120 karakter olabilir"]),
        .init(
            name: "uzun not",
            draft: draft(notes: String(repeating: "a", count: TaskDraft.notesMaxLength + 1)),
            errors: [.notes: "Not en fazla 1.000 karakter olabilir"]),
        .init(
            name: "weekly + gün yok", draft: draft(frequency: .weekly, weekdays: []),
            errors: [.weekdays: "En az bir gün seç"]),
        .init(
            name: "weekly + yalnızca geçersiz gün", draft: draft(frequency: .weekly, weekdays: [0, 8]),
            errors: [.weekdays: "En az bir gün seç"]),
        .init(
            name: "ödev + son tarih yok", draft: draft(kind: .assignment, dueDate: ""),
            errors: [.dueDate: "Son tarih gerekli"]),
        .init(
            name: "ödev + yalnızca boşluk tarih", draft: draft(kind: .assignment, dueDate: "  "),
            errors: [.dueDate: "Son tarih gerekli"]),
        .init(
            name: "ödev + biçimsiz tarih", draft: draft(kind: .assignment, dueDate: "19.11.2026"),
            errors: [.dueDate: "Geçerli bir tarih gir"]),
        .init(
            name: "ödev + olmayan gün", draft: draft(kind: .assignment, dueDate: "2026-02-30"),
            errors: [.dueDate: "Geçerli bir tarih gir"]),
        .init(
            name: "ödev + olmayan ay", draft: draft(kind: .assignment, dueDate: "2026-13-01"),
            errors: [.dueDate: "Geçerli bir tarih gir"]),
        .init(
            name: "miktar sıfır", draft: draft(targetQuantity: "0"),
            errors: [.targetQuantity: "Pozitif bir tam sayı gir"]),
        .init(
            name: "miktar ondalık", draft: draft(targetQuantity: "2,5"),
            errors: [.targetQuantity: "Pozitif bir tam sayı gir"]),
        .init(
            name: "miktar metin", draft: draft(targetQuantity: "çok"),
            errors: [.targetQuantity: "Pozitif bir tam sayı gir"]),
        .init(
            name: "miktar büyük", draft: draft(targetQuantity: "10001"),
            errors: [.targetQuantity: "En fazla 10.000 olabilir"]),
        .init(
            name: "uzun birim",
            draft: draft(quantityUnit: String(repeating: "a", count: TaskDraft.unitMaxLength + 1)),
            errors: [.quantityUnit: "Birim en fazla 24 karakter olabilir"]),
    ]

    @Test("geçersiz taslak → hata", arguments: errorCases)
    func invalid(_ testCase: ErrorCase) {
        #expect(errors(testCase.draft.validate()) == testCase.errors)
    }

    @Test("rutinde geçersiz son tarih ve ödevde boş gün listesi hata değildir")
    func irrelevantFieldsIgnored() {
        #expect(validValues(draft(dueDate: "x").validate()) != nil)
        #expect(validValues(draft(kind: .assignment, frequency: .weekly, dueDate: today).validate()) != nil)
    }

    @Test("birden çok hatayı birlikte döner")
    func multipleErrors() {
        let result = draft(kind: .assignment, title: "", dueDate: "", targetQuantity: "-1").validate()
        #expect(result == .invalid([
            .title: "Başlık gerekli",
            .dueDate: "Son tarih gerekli",
            .targetQuantity: "Pozitif bir tam sayı gir",
        ]))
    }

    @Test("validate girdiyi değiştirmez (değer semantiği)")
    func doesNotMutateInput() {
        let input = draft(title: "  Paragraf ", frequency: .weekly, weekdays: [5, 1], targetQuantity: " 4 ")
        let copy = input
        _ = input.validate()
        #expect(input == copy)
    }

    @Test("Field.allCases altı alanı kapsar")
    func fieldCases() {
        #expect(TaskDraft.Field.allCases.count == 6)
    }
}
