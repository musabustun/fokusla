import Foundation
import Testing

@testable import FokusDomain

// Kitap etiketleri ve tr-TR biçimleri — web `features/books/bookLabels.ts` vakalarıyla uyumlu.

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

private let istanbul = calendar("Europe/Istanbul")

private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso)!
}

private struct TextCase<Input: Sendable>: Sendable, CustomTestStringConvertible {
    let input: Input
    let expected: String
    var testDescription: String { "\(input) → \(expected)" }
}

private let kindCases: [TextCase<BookKind>] = [
    TextCase(input: .questionBank, expected: "Soru bankası"),
    TextCase(input: .lecture, expected: "Konu anlatımı"),
    TextCase(input: .practiceExam, expected: "Deneme"),
    TextCase(input: .other, expected: "Diğer"),
]

private let unitLabelCases: [TextCase<BookUnit>] = [
    TextCase(input: .test, expected: "Test"),
    TextCase(input: .page, expected: "Sayfa"),
    TextCase(input: .section, expected: "Bölüm"),
]

private let unitNounCases: [TextCase<BookUnit>] = [
    TextCase(input: .test, expected: "test"),
    TextCase(input: .page, expected: "sayfa"),
    TextCase(input: .section, expected: "bölüm"),
]

private let statusCases: [TextCase<BooksCalc.BookStatus>] = [
    TextCase(input: .notStarted, expected: "Başlanmadı"),
    TextCase(input: .inProgress, expected: "Devam ediyor"),
    TextCase(input: .completed, expected: "Tamamlandı"),
    TextCase(input: .archived, expected: "Arşivlendi"),
]

private let intCases: [TextCase<Int>] = [
    TextCase(input: 0, expected: "0"),
    TextCase(input: 34, expected: "34"),
    TextCase(input: 999, expected: "999"),
    TextCase(input: 1234, expected: "1.234"),
    TextCase(input: 1_234_567, expected: "1.234.567"),
    TextCase(input: -12, expected: "-12"),
]

private let doubleCases: [TextCase<Double>] = [
    TextCase(input: 0.5, expected: "0,5"),
    TextCase(input: 1234.5, expected: "1.234,5"),
    TextCase(input: 2.0, expected: "2"),
]

private let percentCases: [TextCase<Double>] = [
    TextCase(input: 0, expected: "%0"),
    TextCase(input: 0.456, expected: "%46"),
    TextCase(input: 0.455, expected: "%46"),
    TextCase(input: 0.7, expected: "%70"),
    TextCase(input: 1, expected: "%100"),
]

private struct PositionCase: Sendable, CustomTestStringConvertible {
    let unit: BookUnit
    let reached: Int
    let expected: String
    var testDescription: String { "\(unit) \(reached) → \(expected)" }
}

private let positionCases: [PositionCase] = [
    PositionCase(unit: .test, reached: 34, expected: "Test 34"),
    PositionCase(unit: .page, reached: 210, expected: "Sayfa 210"),
    PositionCase(unit: .section, reached: 3, expected: "Bölüm 3"),
    PositionCase(unit: .page, reached: 1210, expected: "Sayfa 1.210"),
]

private struct ProgressCountCase: Sendable, CustomTestStringConvertible {
    let unit: BookUnit
    let reached: Int
    let total: Int?
    let expected: String
    var testDescription: String { "\(unit) \(reached)/\(String(describing: total)) → \(expected)" }
}

private let progressCountCases: [ProgressCountCase] = [
    ProgressCountCase(unit: .test, reached: 34, total: 120, expected: "34 / 120 test"),
    ProgressCountCase(unit: .page, reached: 1210, total: 1500, expected: "1.210 / 1.500 sayfa"),
    ProgressCountCase(unit: .test, reached: 34, total: nil, expected: "34 test"),
    ProgressCountCase(unit: .section, reached: 3, total: 0, expected: "3 bölüm"),
    ProgressCountCase(unit: .section, reached: 3, total: -4, expected: "3 bölüm"),
]

private struct PaceCase: Sendable, CustomTestStringConvertible {
    let unit: BookUnit
    let pace: Double?
    let expected: String?
    var testDescription: String { "\(unit) \(String(describing: pace)) → \(String(describing: expected))" }
}

private let paceCases: [PaceCase] = [
    PaceCase(unit: .test, pace: nil, expected: nil),
    PaceCase(unit: .test, pace: 12, expected: "haftada ~12 test"),
    PaceCase(unit: .page, pace: 11.6, expected: "haftada ~12 sayfa"),
    PaceCase(unit: .page, pace: 11.4, expected: "haftada ~11 sayfa"),
    PaceCase(unit: .section, pace: 2.5, expected: "haftada ~3 bölüm"),
    PaceCase(unit: .page, pace: 0, expected: "haftada ~0 sayfa"),
    PaceCase(unit: .page, pace: 1500, expected: "haftada ~1.500 sayfa"),
]

private struct DayCase: Sendable, CustomTestStringConvertible {
    let date: String
    let expected: String
    var testDescription: String { "\(date) → \(expected)" }
}

private let dayNow = at("2026-11-19T12:00:00.000Z")

private let dayCases: [DayCase] = [
    DayCase(date: "2026-11-19T12:00:00.000Z", expected: "19 Kasım"),
    DayCase(date: "2026-01-05T09:00:00.000Z", expected: "5 Ocak"),
    DayCase(date: "2025-11-19T12:00:00.000Z", expected: "19 Kasım 2025"),
    DayCase(date: "2027-03-02T12:00:00.000Z", expected: "2 Mart 2027"),
    // İstanbul (UTC+3) saatiyle ertesi gün: gün, takvimin saat diliminde okunur.
    DayCase(date: "2026-11-18T22:00:00.000Z", expected: "19 Kasım"),
    // Yıl karşılaştırması da takvimin saat diliminde: UTC'de 2025, İstanbul'da 2026.
    DayCase(date: "2025-12-31T22:00:00.000Z", expected: "1 Ocak"),
]

@Suite("BooksFormat")
struct BooksFormatTests {
    @Test("kindLabel", arguments: kindCases)
    fileprivate func kindLabel(_ testCase: TextCase<BookKind>) {
        #expect(BooksFormat.kindLabel(testCase.input) == testCase.expected)
    }

    @Test("unitLabel", arguments: unitLabelCases)
    fileprivate func unitLabel(_ testCase: TextCase<BookUnit>) {
        #expect(BooksFormat.unitLabel(testCase.input) == testCase.expected)
    }

    @Test("unitNoun", arguments: unitNounCases)
    fileprivate func unitNoun(_ testCase: TextCase<BookUnit>) {
        #expect(BooksFormat.unitNoun(testCase.input) == testCase.expected)
    }

    @Test("statusLabel", arguments: statusCases)
    fileprivate func statusLabel(_ testCase: TextCase<BooksCalc.BookStatus>) {
        #expect(BooksFormat.statusLabel(testCase.input) == testCase.expected)
    }

    @Test("number(Int)", arguments: intCases)
    fileprivate func numberInt(_ testCase: TextCase<Int>) {
        #expect(BooksFormat.number(testCase.input) == testCase.expected)
    }

    @Test("number(Double)", arguments: doubleCases)
    fileprivate func numberDouble(_ testCase: TextCase<Double>) {
        #expect(BooksFormat.number(testCase.input) == testCase.expected)
    }

    @Test("percent", arguments: percentCases)
    fileprivate func percent(_ testCase: TextCase<Double>) {
        #expect(BooksFormat.percent(testCase.input) == testCase.expected)
    }

    @Test("position", arguments: positionCases)
    fileprivate func position(_ testCase: PositionCase) {
        #expect(BooksFormat.position(testCase.unit, reached: testCase.reached) == testCase.expected)
    }

    @Test("progressCount", arguments: progressCountCases)
    fileprivate func progressCount(_ testCase: ProgressCountCase) {
        let result = BooksFormat.progressCount(
            testCase.unit, reached: testCase.reached, total: testCase.total)
        #expect(result == testCase.expected)
    }

    @Test("pace", arguments: paceCases)
    fileprivate func pace(_ testCase: PaceCase) {
        #expect(BooksFormat.pace(testCase.unit, pacePerWeek: testCase.pace) == testCase.expected)
    }

    @Test("day", arguments: dayCases)
    fileprivate func day(_ testCase: DayCase) {
        #expect(BooksFormat.day(at(testCase.date), now: dayNow, calendar: istanbul) == testCase.expected)
    }

    @Test("day: calendar varsayılanı .current ile de çalışır")
    func dayWithDefaultCalendar() {
        let result = BooksFormat.day(dayNow, now: dayNow)
        #expect(result.hasSuffix("Kasım") || result.hasSuffix("Aralık"))
    }

    @Test("addDays: yerel gün aritmetiği (DST'de saat korunur)")
    func addDaysKeepsLocalTime() {
        // Avrupa/İstanbul'da DST yok; New York'ta 2026-11-01'de saatler geri alınır.
        let newYork = calendar("America/New_York")
        let start = at("2026-10-31T16:00:00.000Z")  // New York 12:00 (EDT)

        let result = BooksFormat.addDays(start, 2, calendar: newYork)

        #expect(result == at("2026-11-02T17:00:00.000Z"))  // New York 12:00 (EST)
        #expect(BooksFormat.addDays(dayNow, 0, calendar: istanbul) == dayNow)
        #expect(BooksFormat.addDays(dayNow, -3, calendar: istanbul) == at("2026-11-16T12:00:00.000Z"))
    }

    @Test("addDays: calendar varsayılanı .current ile de çalışır")
    func addDaysWithDefaultCalendar() {
        #expect(BooksFormat.addDays(dayNow, 1) > dayNow)
    }
}
