import Foundation
import Testing

@testable import FokusDomain

// Analiz modülü biçimleyici ve satır metni testleri — web `format.test.ts` + `labels.test.ts` ile aynı
// vakalar. Saat dilimi sabit (Europe/Istanbul) ve `calendar:` her çağrıda açıkça verilir.

private let istanbul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10) -> Date {
    istanbul.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

// MARK: - Sayı biçimleri

private struct NumberCase: Sendable, CustomTestStringConvertible {
    var input: Double
    var expected: String
    var testDescription: String { "\(input) → \(expected)" }
}

private let netCases: [NumberCase] = [
    NumberCase(input: 12.75, expected: "12,75"),
    NumberCase(input: 8, expected: "8,00"),
    NumberCase(input: 0, expected: "0,00"),
    NumberCase(input: -0.0, expected: "0,00"),
    NumberCase(input: -1.25, expected: "-1,25"),
    NumberCase(input: 1240.5, expected: "1.240,50"),
    NumberCase(input: 0.126, expected: "0,13"),
]

private let percentCases: [NumberCase] = [
    NumberCase(input: 0.5, expected: "%50"),
    NumberCase(input: 0.75, expected: "%75"),
    NumberCase(input: 1, expected: "%100"),
    NumberCase(input: 0, expected: "%0"),
    NumberCase(input: 0.666, expected: "%67"),
    NumberCase(input: .nan, expected: "%0"),
    NumberCase(input: .infinity, expected: "%0"),
]

private struct TextCase: Sendable, CustomTestStringConvertible {
    var name: String
    var actual: String
    var expected: String
    var testDescription: String { name }
}

private let labelCases: [TextCase] = [
    TextCase(name: "formatCount 1240", actual: AnalysisFormat.formatCount(1240), expected: "1.240"),
    TextCase(name: "formatCount 7", actual: AnalysisFormat.formatCount(7), expected: "7"),
    TextCase(name: "formatQuestionCount 24", actual: AnalysisFormat.formatQuestionCount(24), expected: "24 soru"),
    TextCase(
        name: "formatQuestionCount 1500", actual: AnalysisFormat.formatQuestionCount(1500),
        expected: "1.500 soru"),
    TextCase(name: "formatNetValue 11", actual: AnalysisFormat.formatNetValue(11), expected: "11,00 net"),
    TextCase(name: "formatNetValue -0.5", actual: AnalysisFormat.formatNetValue(-0.5), expected: "-0,50 net"),
    TextCase(
        name: "formatAnswerCounts 12/4/4",
        actual: AnalysisFormat.formatAnswerCounts(correct: 12, wrong: 4, blank: 4), expected: "12D 4Y 4B"),
    TextCase(
        name: "formatAnswerCounts 0/0/0",
        actual: AnalysisFormat.formatAnswerCounts(correct: 0, wrong: 0, blank: 0), expected: "0D 0Y 0B"),
    TextCase(
        name: "formatAnswerCounts binlik",
        actual: AnalysisFormat.formatAnswerCounts(correct: 1240, wrong: 0, blank: 0), expected: "1.240D 0Y 0B"),
]

@Suite("sayı biçimleri")
struct AnalysisNumberFormatTests {
    @Test("formatNet", arguments: netCases)
    fileprivate func formatNet(_ c: NumberCase) {
        #expect(AnalysisFormat.formatNet(c.input) == c.expected)
    }

    @Test("formatPercent", arguments: percentCases)
    fileprivate func formatPercent(_ c: NumberCase) {
        #expect(AnalysisFormat.formatPercent(c.input) == c.expected)
    }

    @Test("sayı ve etiket biçimleri", arguments: labelCases)
    fileprivate func labels(_ c: TextCase) {
        #expect(c.actual == c.expected)
    }

    @Test("sabit metinler")
    func constants() {
        #expect(AnalysisFormat.noResultsText == "Henüz test yok")
        #expect(AnalysisFormat.unknownSourceText == "Kaynak belirtilmedi")
        #expect(AnalysisFormat.locale.identifier == "tr_TR")
    }
}

// MARK: - Tarih biçimleri

@Suite("tarih biçimleri")
struct AnalysisDateFormatTests {
    private let dateCases: [TextCase] = [
        TextCase(
            name: "formatDate 19 Kas 2026", actual: AnalysisFormat.formatDate(local(2026, 11, 19), calendar: istanbul),
            expected: "19 Kas 2026"),
        TextCase(
            name: "formatDate 1 Oca 2027 (gece yarısı)",
            actual: AnalysisFormat.formatDate(local(2027, 1, 1, 0), calendar: istanbul), expected: "1 Oca 2027"),
        TextCase(
            name: "formatShortDate 19 Kas (23:00)",
            actual: AnalysisFormat.formatShortDate(local(2026, 11, 19, 23), calendar: istanbul), expected: "19 Kas"),
        TextCase(
            name: "formatShortDay 2026-11-19",
            actual: AnalysisFormat.formatShortDay("2026-11-19", calendar: istanbul), expected: "19 Kas"),
        TextCase(
            name: "formatShortDay 2027-06-01",
            actual: AnalysisFormat.formatShortDay("2027-06-01", calendar: istanbul), expected: "1 Haz"),
        TextCase(
            name: "formatShortDay geçersiz dizge olduğu gibi döner",
            actual: AnalysisFormat.formatShortDay("abc", calendar: istanbul), expected: "abc"),
        TextCase(
            name: "formatShortDay eksik parça olduğu gibi döner",
            actual: AnalysisFormat.formatShortDay("2026-11", calendar: istanbul), expected: "2026-11"),
        TextCase(
            name: "formatShortDay boş dizge olduğu gibi döner",
            actual: AnalysisFormat.formatShortDay("", calendar: istanbul), expected: ""),
    ]

    @Test("tarih biçimleri")
    func dates() {
        for c in dateCases { #expect(c.actual == c.expected, Comment(rawValue: c.name)) }
    }

    @Test("gün, UTC'de bir önceki güne düşse bile yerel güne göre biçimlenir")
    func localDayNotUTC() {
        // 00:30 İstanbul (UTC+3) = önceki gün 21:30 UTC.
        let date = local(2026, 11, 19, 0)
        #expect(AnalysisFormat.formatShortDate(date, calendar: istanbul) == "19 Kas")
    }

    @Test("resultSubtitle: tarih ve D/Y/B")
    func resultSubtitle() {
        let text = AnalysisFormat.resultSubtitle(
            takenAt: local(2026, 11, 19), correct: 12, wrong: 4, blank: 4, calendar: istanbul)
        #expect(text == "19 Kas 2026 · 12D 4Y 4B")
    }
}

// MARK: - Özet metinleri

private func makeSummary(
    testCount: Int = 2, totalQuestions: Int = 24, net: Double = 12.75, accuracy: Double = 0.64,
    lastTakenAt: Date? = local(2026, 11, 19)
) -> TestSummary {
    TestSummary(
        testCount: testCount, totalQuestions: totalQuestions, correct: 15, wrong: 9, blank: 0, net: net,
        accuracy: accuracy, netRatio: 0.53, lastTakenAt: lastTakenAt)
}

private let summary = makeSummary()
private let emptySummary = makeSummary(testCount: 0, totalQuestions: 0, net: 0, accuracy: 0, lastTakenAt: nil)

private struct OptionalTextCase: Sendable, CustomTestStringConvertible {
    var name: String
    var actual: String?
    var expected: String?
    var testDescription: String { name }
}

@Suite("özet metinleri")
struct AnalysisSummaryTextTests {
    private let stringCases: [TextCase] = [
        TextCase(name: "subjectStatText", actual: AnalysisFormat.subjectStatText(summary), expected: "12,75 net · %64"),
        TextCase(
            name: "subjectStatText özet yok", actual: AnalysisFormat.subjectStatText(nil),
            expected: AnalysisFormat.noResultsText),
        TextCase(
            name: "subjectStatText test yok", actual: AnalysisFormat.subjectStatText(emptySummary),
            expected: AnalysisFormat.noResultsText),
        TextCase(name: "topicStatText", actual: AnalysisFormat.topicStatText(summary), expected: "%64 · 12,75 net"),
        TextCase(
            name: "topicStatText özet yok", actual: AnalysisFormat.topicStatText(nil),
            expected: AnalysisFormat.noResultsText),
        TextCase(
            name: "topicStatText test yok", actual: AnalysisFormat.topicStatText(emptySummary),
            expected: AnalysisFormat.noResultsText),
    ]

    private let detailCases: [OptionalTextCase] = [
        OptionalTextCase(
            name: "topicDetailText", actual: AnalysisFormat.topicDetailText(summary, calendar: istanbul),
            expected: "24 soru · son 19 Kas"),
        OptionalTextCase(
            name: "topicDetailText lastTakenAt nil",
            actual: AnalysisFormat.topicDetailText(makeSummary(lastTakenAt: nil), calendar: istanbul),
            expected: "24 soru"),
        OptionalTextCase(
            name: "topicDetailText test yok",
            actual: AnalysisFormat.topicDetailText(emptySummary, calendar: istanbul), expected: nil),
        OptionalTextCase(
            name: "topicDetailText özet yok", actual: AnalysisFormat.topicDetailText(nil, calendar: istanbul),
            expected: nil),
    ]

    @Test("özet metinleri")
    func strings() {
        for c in stringCases { #expect(c.actual == c.expected, Comment(rawValue: c.name)) }
    }

    @Test("topicDetailText")
    func details() {
        for c in detailCases { #expect(c.actual == c.expected, Comment(rawValue: c.name)) }
    }
}

// MARK: - resultTitle

private struct TitleCase: Sendable, CustomTestStringConvertible {
    var name: String
    var bookTitle: String?
    var sourceName: String?
    var label: String?
    var expected: String
    var testDescription: String { name }
}

private let titleCases: [TitleCase] = [
    TitleCase(name: "kitap + etiket", bookTitle: "Karekök", sourceName: nil, label: "Test 12", expected: "Karekök · Test 12"),
    TitleCase(name: "yalnızca kitap", bookTitle: "Karekök", sourceName: nil, label: nil, expected: "Karekök"),
    TitleCase(name: "kitap serbest kaynaktan önce gelir", bookTitle: "Karekök", sourceName: "Fasikül", label: nil, expected: "Karekök"),
    TitleCase(name: "silinmiş kitap → serbest kaynak", bookTitle: nil, sourceName: "Fasikül", label: nil, expected: "Fasikül"),
    TitleCase(name: "serbest kaynak + etiket", bookTitle: nil, sourceName: "Okul fasikülü", label: "s. 45", expected: "Okul fasikülü · s. 45"),
    TitleCase(name: "boşluklu kaynak yok sayılır", bookTitle: nil, sourceName: "   ", label: "Deneme 3", expected: "Deneme 3"),
    TitleCase(name: "kaynak ve etiket kırpılır", bookTitle: nil, sourceName: "  Fasikül ", label: " s. 1 ", expected: "Fasikül · s. 1"),
    TitleCase(name: "hiçbiri yok", bookTitle: nil, sourceName: nil, label: nil, expected: AnalysisFormat.unknownSourceText),
    TitleCase(name: "boşluklu etiket yok sayılır", bookTitle: nil, sourceName: nil, label: "  ", expected: AnalysisFormat.unknownSourceText),
]

@Suite("resultTitle")
struct AnalysisResultTitleTests {
    @Test("resultTitle", arguments: titleCases)
    fileprivate func resultTitle(_ c: TitleCase) {
        #expect(
            AnalysisFormat.resultTitle(bookTitle: c.bookTitle, sourceName: c.sourceName, label: c.label)
                == c.expected)
    }
}
