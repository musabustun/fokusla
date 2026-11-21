import Foundation
import Testing

@testable import FokusDomain

// Test sonucu formu testleri — web `testResultForm.test.ts` ile aynı vakalar (aynı adlar). Web'deki
// tarih metni (boş/biçimsiz) hataları Swift'te `Date` tipi olduğundan yoktur. Saat dilimi sabit
// (Europe/Istanbul) ve `calendar:` her çağrıda açıkça verilir.

private typealias Form = TestResultForm

private let istanbul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
    istanbul.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

private let today = local(2026, 11, 19, 21, 45, 10)
private let subject = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
private let topic = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
private let book = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!

/// Test başına yalnızca ilgili alanları veren form (varsayılan ders seçili, tarih bugün).
private func form(
    subjectId: UUID? = subject, topicId: UUID? = nil, source: Form.Source = .none, sourceName: String = "",
    label: String = "", questionCount: String = "", correct: String = "", wrong: String = "",
    blank: String = "", blankAuto: Bool = true, date: Date = today
) -> Form.Values {
    Form.Values(
        subjectId: subjectId, topicId: topicId, source: source, sourceName: sourceName, label: label,
        questionCount: questionCount, correct: correct, wrong: wrong, blank: blank, blankAuto: blankAuto,
        date: date)
}

private func input(
    topicId: UUID? = nil, bookId: UUID? = nil, sourceName: String? = nil, label: String? = nil,
    correct: Int, wrong: Int, blank: Int, date: Date = today
) -> Form.Input {
    Form.Input(
        subjectId: subject, topicId: topicId, bookId: bookId, sourceName: sourceName, label: label,
        correct: correct, wrong: wrong, blank: blank, date: date)
}

// MARK: - emptyValues / values

@Suite("emptyValues")
struct TestResultFormEmptyValuesTests {
    @Test("varsayılanlarla boş form üretir")
    func defaults() {
        #expect(
            Form.emptyValues(today: today)
                == Form.Values(
                    subjectId: nil, topicId: nil, source: .none, sourceName: "", label: "", questionCount: "",
                    correct: "", wrong: "", blank: "", blankAuto: true, date: today))
    }

    @Test("ders ve konu varsayılanlarını alır; nil konu boş olur")
    func subjectAndTopic() {
        let both = Form.emptyValues(today: today, subjectId: subject, topicId: topic)
        #expect(both.subjectId == subject)
        #expect(both.topicId == topic)
        #expect(Form.emptyValues(today: today, subjectId: subject, topicId: nil).topicId == nil)
    }
}

private struct FromResultCase: Sendable, CustomTestStringConvertible {
    var name: String
    var topicId: UUID?
    var bookId: UUID?
    var sourceName: String?
    var label: String?
    var expectedSource: Form.Source
    var expectedSourceName: String
    var expectedLabel: String
    var testDescription: String { name }
}

private let fromResultCases: [FromResultCase] = [
    FromResultCase(
        name: "kitapsız, kaynaksız", topicId: topic, bookId: nil, sourceName: nil, label: "Test 12",
        expectedSource: .none, expectedSourceName: "", expectedLabel: "Test 12"),
    FromResultCase(
        name: "kayıtlı kitap", topicId: topic, bookId: book, sourceName: nil, label: "Test 12",
        expectedSource: .book(book), expectedSourceName: "", expectedLabel: "Test 12"),
    FromResultCase(
        name: "kayıtlı kitap varken kaynak adı atılır", topicId: topic, bookId: book, sourceName: "eski",
        label: nil, expectedSource: .book(book), expectedSourceName: "", expectedLabel: ""),
    FromResultCase(
        name: "serbest kaynak", topicId: topic, bookId: nil, sourceName: "Okul fasikülü", label: "Test 12",
        expectedSource: .other, expectedSourceName: "Okul fasikülü", expectedLabel: "Test 12"),
    FromResultCase(
        name: "boş kaynak adı kaynaksız sayılır", topicId: nil, bookId: nil, sourceName: "", label: nil,
        expectedSource: .none, expectedSourceName: "", expectedLabel: ""),
    FromResultCase(
        name: "sourceName alanı olmayan eski kayıt", topicId: nil, bookId: nil, sourceName: nil, label: nil,
        expectedSource: .none, expectedSourceName: "", expectedLabel: ""),
]

@Suite("values(…) — kayıttan form")
struct TestResultFormFromResultTests {
    @Test("kayıttan form", arguments: fromResultCases)
    fileprivate func fromResult(_ c: FromResultCase) {
        let values = Form.values(
            subjectId: subject, topicId: c.topicId, bookId: c.bookId, sourceName: c.sourceName,
            label: c.label, correct: 10, wrong: 4, blank: 6, takenAt: today)
        #expect(values.source == c.expectedSource)
        #expect(values.sourceName == c.expectedSourceName)
        #expect(values.label == c.expectedLabel)
        #expect(values.topicId == c.topicId)
    }

    @Test("soru sayısını D+Y+B, tarihi kayıt günü olarak doldurur; otomatik boş kapalı")
    func countsAndDate() {
        let values = Form.values(
            subjectId: subject, topicId: topic, bookId: nil, sourceName: nil, label: "Test 12",
            correct: 10, wrong: 4, blank: 6, takenAt: today)
        #expect(values.subjectId == subject)
        #expect(values.questionCount == "20")
        #expect(values.correct == "10")
        #expect(values.wrong == "4")
        #expect(values.blank == "6")
        #expect(!values.blankAuto)
        #expect(values.date == today)
    }
}

// MARK: - resolveBlank

private struct BlankCase: Sendable, CustomTestStringConvertible {
    var q: String
    var c: String
    var w: String
    var b: String
    var auto: Bool
    var expected: String
    var testDescription: String { "q=\(q) c=\(c) w=\(w) auto=\(auto) → boş \"\(expected)\"" }
}

private let blankCases: [BlankCase] = [
    BlankCase(q: "20", c: "12", w: "3", b: "", auto: true, expected: "5"),
    BlankCase(q: "20", c: "", w: "", b: "", auto: true, expected: "20"),
    BlankCase(q: "10", c: "8", w: "5", b: "", auto: true, expected: "-3"),
    BlankCase(q: "", c: "8", w: "5", b: "", auto: true, expected: ""),
    BlankCase(q: "x", c: "8", w: "5", b: "1", auto: true, expected: "1"),
    BlankCase(q: "0", c: "0", w: "0", b: "1", auto: true, expected: "1"),
    BlankCase(q: "20", c: "1.5", w: "5", b: "", auto: true, expected: ""),
    BlankCase(q: "20", c: "5", w: "x", b: "2", auto: true, expected: "2"),
    BlankCase(q: "20", c: "12", w: "3", b: "1", auto: false, expected: "1"),
]

@Suite("resolveBlank")
struct TestResultFormResolveBlankTests {
    @Test("boş hesaplama", arguments: blankCases)
    fileprivate func resolve(_ c: BlankCase) {
        let values = form(questionCount: c.q, correct: c.c, wrong: c.w, blank: c.b, blankAuto: c.auto)
        #expect(Form.resolveBlank(values).blank == c.expected)
    }

    @Test("girdiyi değiştirmez")
    func doesNotMutate() {
        let values = form(questionCount: "10", correct: "5")
        let copy = values
        _ = Form.resolveBlank(values)
        #expect(values == copy)
    }

    @Test("kenar boşlukları kırpılır")
    func trimsWhitespace() {
        let values = form(questionCount: " 20 ", correct: " 12", wrong: "3 ")
        #expect(Form.resolveBlank(values).blank == "5")
    }
}

// MARK: - previewCounts

private struct PreviewCase: Sendable, CustomTestStringConvertible {
    var name: String
    var values: Form.Values
    var expected: Form.Counts?
    var testDescription: String { name }
}

private let previewCases: [PreviewCase] = [
    PreviewCase(
        name: "otomatik boş çözülür", values: form(questionCount: "20", correct: "12", wrong: "4"),
        expected: Form.Counts(correct: 12, wrong: 4, blank: 4)),
    PreviewCase(name: "boş form 0/0/0", values: form(), expected: Form.Counts(correct: 0, wrong: 0, blank: 0)),
    PreviewCase(name: "negatif doğru → nil", values: form(correct: "-1"), expected: nil),
    PreviewCase(
        name: "D+Y soru sayısını aşar → nil", values: form(questionCount: "5", correct: "4", wrong: "4"),
        expected: nil),
    PreviewCase(name: "geçersiz yanlış → nil", values: form(correct: "1", wrong: "x"), expected: nil),
    PreviewCase(
        name: "geçersiz elle boş → nil", values: form(correct: "1", blank: "a", blankAuto: false),
        expected: nil),
]

@Suite("previewCounts")
struct TestResultFormPreviewTests {
    @Test("önizleme sayıları", arguments: previewCases)
    fileprivate func preview(_ c: PreviewCase) {
        #expect(Form.previewCounts(c.values) == c.expected)
    }
}

// MARK: - validate — geçerli

private struct ValidCase: Sendable, CustomTestStringConvertible {
    var name: String
    var values: Form.Values
    var expected: Form.Input
    var testDescription: String { name }
}

private let validCases: [ValidCase] = [
    ValidCase(
        name: "otomatik boşu hesaplar, metinleri kırpar, kitap yoksa kaynak nil",
        values: form(topicId: topic, label: "  Test 12 ", questionCount: "20", correct: "12", wrong: "4"),
        expected: input(topicId: topic, label: "Test 12", correct: 12, wrong: 4, blank: 4)),
    ValidCase(
        name: "serbest kaynak",
        values: form(source: .other, sourceName: "  Okul fasikülü ", correct: "1"),
        expected: input(sourceName: "Okul fasikülü", correct: 1, wrong: 0, blank: 0)),
    ValidCase(
        name: "boş serbest kaynak → nil", values: form(source: .other, sourceName: "   ", correct: "1"),
        expected: input(correct: 1, wrong: 0, blank: 0)),
    ValidCase(
        name: "kayıtlı kitap seçiliyse kaynak adı yok sayılır",
        values: form(source: .book(book), sourceName: "eski metin", correct: "1"),
        expected: input(bookId: book, correct: 1, wrong: 0, blank: 0)),
    ValidCase(
        name: "kitap yok seçiliyse kaynak adı yok sayılır",
        values: form(source: .none, sourceName: "eski metin", correct: "1"),
        expected: input(correct: 1, wrong: 0, blank: 0)),
    ValidCase(
        name: "soru sayısı boşken boş D/Y/B 0 sayılır",
        values: form(correct: "7", wrong: "", blank: "", blankAuto: false),
        expected: input(correct: 7, wrong: 0, blank: 0)),
    ValidCase(
        name: "otomatik boş kapalı, toplam soru sayısına eşit",
        values: form(questionCount: "10", correct: "5", wrong: "3", blank: "2", blankAuto: false),
        expected: input(correct: 5, wrong: 3, blank: 2)),
    ValidCase(
        name: "geçmiş tarih", values: form(correct: "1", date: local(2025, 2, 28)),
        expected: input(correct: 1, wrong: 0, blank: 0, date: local(2025, 2, 28))),
    ValidCase(
        name: "bugünün erken saati geçerli (gün karşılaştırılır)",
        values: form(correct: "1", date: local(2026, 11, 19, 0, 5)),
        expected: input(correct: 1, wrong: 0, blank: 0, date: local(2026, 11, 19, 0, 5))),
    ValidCase(
        name: "tam uzunlukta (80) etiket geçerli",
        values: form(label: String(repeating: "x", count: 80), correct: "1"),
        expected: input(label: String(repeating: "x", count: 80), correct: 1, wrong: 0, blank: 0)),
]

// MARK: - validate — hatalar

private struct InvalidCase: Sendable, CustomTestStringConvertible {
    var name: String
    var values: Form.Values
    var errors: [Form.Field: String]
    var testDescription: String { name }
}

private let tooLong = String(repeating: "x", count: Form.maxTextLength + 1)

private let invalidCases: [InvalidCase] = [
    InvalidCase(
        name: "ders yok", values: form(subjectId: nil, correct: "1"),
        errors: [.subject: Form.Message.subjectRequired]),
    InvalidCase(
        name: "negatif doğru", values: form(correct: "-1"), errors: [.correct: Form.Message.countInvalid]),
    InvalidCase(
        name: "ondalık yanlış", values: form(correct: "1", wrong: "1.5"),
        errors: [.wrong: Form.Message.countInvalid]),
    InvalidCase(
        name: "harfli boş (otomatik kapalı)", values: form(correct: "1", blank: "a", blankAuto: false),
        errors: [.blank: Form.Message.countInvalid]),
    InvalidCase(
        name: "negatif boş (otomatik kapalı)", values: form(correct: "1", blank: "-1", blankAuto: false),
        errors: [.blank: Form.Message.countInvalid]),
    InvalidCase(
        name: "soru sayısı 0", values: form(questionCount: "0", correct: "1"),
        errors: [.questionCount: Form.Message.questionCountInvalid]),
    InvalidCase(
        name: "soru sayısı geçersiz", values: form(questionCount: "1,5", correct: "1"),
        errors: [.questionCount: Form.Message.questionCountInvalid]),
    InvalidCase(
        name: "soru sayısı geçersiz ve doğru geçersiz",
        values: form(questionCount: "x", correct: "-1"),
        errors: [
            .questionCount: Form.Message.questionCountInvalid, .correct: Form.Message.countInvalid,
        ]),
    InvalidCase(
        name: "otomatik boşta D+Y soru sayısını aşıyor",
        values: form(questionCount: "10", correct: "8", wrong: "5"),
        errors: [.questionCount: Form.Message.sumExceeds]),
    InvalidCase(
        name: "elle boşta D+Y+B soru sayısını aşıyor",
        values: form(questionCount: "10", correct: "5", wrong: "3", blank: "3", blankAuto: false),
        errors: [.questionCount: Form.Message.sumExceeds]),
    InvalidCase(
        name: "elle boşta toplam soru sayısından az",
        values: form(questionCount: "10", correct: "5", wrong: "3", blank: "1", blankAuto: false),
        errors: [.questionCount: Form.Message.sumMismatch(sum: 9, questionCount: 10)]),
    InvalidCase(
        name: "hiç soru yok", values: form(), errors: [.questionCount: Form.Message.noQuestions]),
    InvalidCase(
        name: "gelecek tarih", values: form(correct: "1", date: local(2026, 11, 20, 0, 5)),
        errors: [.date: Form.Message.dateInFuture]),
    InvalidCase(
        name: "uzun etiket", values: form(label: tooLong, correct: "1"),
        errors: [.label: Form.Message.textTooLong]),
    InvalidCase(
        name: "uzun kaynak adı", values: form(source: .other, sourceName: tooLong, correct: "1"),
        errors: [.sourceName: Form.Message.textTooLong]),
    InvalidCase(
        name: "kitap seçiliyken uzun kaynak adı hata vermez ama diğer hatalar sürer",
        values: form(source: .book(book), sourceName: tooLong, correct: "-1"),
        errors: [.correct: Form.Message.countInvalid]),
    InvalidCase(
        name: "birden çok hata birlikte",
        values: form(subjectId: nil, label: tooLong, correct: "1", date: local(2026, 12, 1)),
        errors: [
            .subject: Form.Message.subjectRequired, .date: Form.Message.dateInFuture,
            .label: Form.Message.textTooLong,
        ]),
]

@Suite("validate")
struct TestResultFormValidateTests {
    @Test("geçerli", arguments: validCases)
    fileprivate func valid(_ c: ValidCase) {
        #expect(Form.validate(c.values, today: today, calendar: istanbul) == .valid(c.expected))
    }

    @Test("hatalar", arguments: invalidCases)
    fileprivate func invalid(_ c: InvalidCase) {
        #expect(Form.validate(c.values, today: today, calendar: istanbul) == .invalid(c.errors))
    }

    @Test("sabitler ve mesaj metinleri")
    func messages() {
        #expect(Form.maxTextLength == 80)
        #expect(Form.Message.subjectRequired == "Ders seçmelisin.")
        #expect(Form.Message.countInvalid == "Negatif olmayan bir tam sayı gir.")
        #expect(Form.Message.questionCountInvalid == "Soru sayısı en az 1 olan bir tam sayı olmalı.")
        #expect(Form.Message.sumExceeds == "Doğru + yanlış + boş, soru sayısını aşamaz.")
        #expect(Form.Message.noQuestions == "En az bir soru girmelisin.")
        #expect(Form.Message.dateInFuture == "Gelecekteki bir tarih seçilemez.")
        #expect(Form.Message.textTooLong == "En fazla 80 karakter olabilir.")
        #expect(
            Form.Message.sumMismatch(sum: 9, questionCount: 10)
                == "Doğru + yanlış + boş (9) soru sayısına (10) eşit olmalı.")
    }
}

// MARK: - takenAt

@Suite("takenAt")
struct TestResultFormTakenAtTests {
    private let now = local(2026, 11, 19, 21, 45, 10)

    @Test("bugünse şu anı döner")
    func today() {
        #expect(Form.takenAt(for: local(2026, 11, 19, 0, 5), now: now, calendar: istanbul) == now)
    }

    @Test("başka günse o günün yerel öğleni", arguments: [(2026, 11, 18), (2026, 1, 1), (2025, 12, 31)])
    func otherDay(_ day: (Int, Int, Int)) {
        let picked = local(day.0, day.1, day.2, 8)
        let takenAt = Form.takenAt(for: picked, now: now, calendar: istanbul)
        #expect(takenAt == local(day.0, day.1, day.2, 12))
        let parts = istanbul.dateComponents([.year, .month, .day, .hour], from: takenAt)
        #expect(parts.year == day.0 && parts.month == day.1 && parts.day == day.2 && parts.hour == 12)
    }

    @Test("düzenleme: gün değişmediyse mevcut zaman korunur")
    func editKeepsExistingWhenSameDay() {
        let existing = local(2026, 11, 10, 15, 30)
        let takenAt = Form.takenAt(
            for: local(2026, 11, 10, 0, 1), existing: existing, now: now, calendar: istanbul)
        #expect(takenAt == existing)
    }

    @Test("düzenleme: gün değiştiyse öğlen")
    func editChangedToOtherDay() {
        let existing = local(2026, 11, 10, 15, 30)
        let takenAt = Form.takenAt(
            for: local(2026, 11, 12, 9), existing: existing, now: now, calendar: istanbul)
        #expect(takenAt == local(2026, 11, 12, 12))
    }

    @Test("düzenleme: bugüne taşınırsa şu an")
    func editChangedToToday() {
        let existing = local(2026, 11, 10, 15, 30)
        let takenAt = Form.takenAt(
            for: local(2026, 11, 19, 3), existing: existing, now: now, calendar: istanbul)
        #expect(takenAt == now)
    }
}
