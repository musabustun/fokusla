import Foundation
import Testing

@testable import FokusDomain

// Kimlik/tarih yardımcıları, enum raw value'ları (docs/ARCHITECTURE.md 4.3) ve RecurrenceRule
// JSON biçimi testleri. Web karşılığı: `web/src/domain/ids.test.ts`, `domain/types.ts`.

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso)!
}

private struct IsoDateCase: CustomTestStringConvertible, Sendable {
    let name: String
    let instant: String
    let timeZone: String
    let expected: ISODate
    var testDescription: String { name }
}

@Suite("Identifiers")
struct IdentifiersTests {
    // MARK: isoDate

    private static let isoDateCases: [IsoDateCase] = [
        IsoDateCase(name: "UTC öğleden sonra", instant: "2026-11-19T15:00:00.000Z", timeZone: "UTC", expected: "2026-11-19"),
        IsoDateCase(
            name: "UTC akşamı İstanbul'da ertesi gün", instant: "2026-11-18T22:00:00.000Z",
            timeZone: "Europe/Istanbul", expected: "2026-11-19"),
        IsoDateCase(
            name: "İstanbul gece yarısından 1 ms önce", instant: "2026-11-18T20:59:59.999Z",
            timeZone: "Europe/Istanbul", expected: "2026-11-18"),
        IsoDateCase(
            name: "İstanbul tam gece yarısı", instant: "2026-11-18T21:00:00.000Z",
            timeZone: "Europe/Istanbul", expected: "2026-11-19"),
        IsoDateCase(
            name: "New York'ta UTC sabahı önceki gün", instant: "2026-11-19T03:00:00.000Z",
            timeZone: "America/New_York", expected: "2026-11-18"),
        IsoDateCase(
            name: "yıl sınırı (İstanbul)", instant: "2026-12-31T21:00:00.000Z",
            timeZone: "Europe/Istanbul", expected: "2027-01-01"),
        IsoDateCase(
            name: "artık gün", instant: "2028-02-29T10:00:00.000Z", timeZone: "UTC",
            expected: "2028-02-29"),
        IsoDateCase(
            name: "tek haneli ay ve gün sıfırla doldurulur", instant: "2026-03-05T10:00:00.000Z",
            timeZone: "UTC", expected: "2026-03-05"),
    ]

    @Test("isoDate: saat dilimleri ve gece yarısı", arguments: isoDateCases)
    fileprivate func isoDate(_ testCase: IsoDateCase) {
        let result = Identifiers.isoDate(
            date(testCase.instant), calendar: calendar(testCase.timeZone))
        #expect(result == testCase.expected)
    }

    // MARK: uuidV5

    @Test("uuidV5 RFC 4122 test vektörüyle eşleşir")
    func uuidV5MatchesRfcVector() {
        let dnsNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
        let id = Identifiers.uuidV5(name: "www.example.com", namespace: dnsNamespace)
        #expect(Identifiers.lowercasedString(id) == "2ed6657d-e927-568b-95e1-2665a8aea6a2")
    }

    @Test("catalogEntityId deterministiktir ve anahtara göre değişir")
    func catalogEntityIdIsDeterministic() {
        let first = Identifiers.catalogEntityId("tyt-matematik")
        #expect(first == Identifiers.catalogEntityId("tyt-matematik"))
        #expect(first != Identifiers.catalogEntityId("tyt-geometri"))
    }

    @Test("newId her çağrıda farklı UUID üretir")
    func newIdIsUnique() {
        #expect(Identifiers.newId() != Identifiers.newId())
    }

    // MARK: Weekday

    private static let weekdayCases: [(gregorian: Int, iso: Int)] = [
        (1, 7),  // Pazar
        (2, 1),  // Pazartesi
        (3, 2),
        (4, 3),
        (5, 4),
        (6, 5),
        (7, 6),  // Cumartesi
    ]

    @Test("Weekday.iso(fromGregorian:) tablosu", arguments: weekdayCases)
    func weekdayISO(_ testCase: (gregorian: Int, iso: Int)) {
        #expect(Weekday.iso(fromGregorian: testCase.gregorian) == testCase.iso)
    }

    @Test("Weekday.iso: Calendar'ın weekday bileşeniyle uyumlu (2026-11-19 Perşembe = 4)")
    func weekdayFromCalendar() {
        let gregorian = calendar("UTC").component(.weekday, from: date("2026-11-19T12:00:00.000Z"))
        #expect(Weekday.iso(fromGregorian: gregorian) == 4)
    }

    // MARK: RecurrenceRule

    @Test("RecurrenceRule web JSON biçimini çözer")
    func recurrenceDecodesWebJSON() throws {
        let json = Data(#"{"frequency":"weekly","weekdays":[1,3]}"#.utf8)
        let rule = try JSONDecoder().decode(RecurrenceRule.self, from: json)
        #expect(rule == RecurrenceRule(frequency: .weekly, weekdays: [1, 3]))
        #expect(rule.frequencyValue == .weekly)
    }

    @Test("RecurrenceRule JSON gidiş-dönüşü web biçimini korur")
    func recurrenceRoundTrip() throws {
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [1, 3])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(rule)
        #expect(String(decoding: data, as: UTF8.self) == #"{"frequency":"weekly","weekdays":[1,3]}"#)
        #expect(try JSONDecoder().decode(RecurrenceRule.self, from: data) == rule)
    }

    @Test("RecurrenceRule günlük kural: weekdays varsayılanı boş")
    func recurrenceDaily() throws {
        let rule = RecurrenceRule(frequency: .daily)
        #expect(rule.weekdays.isEmpty)
        let data = try JSONEncoder().encode(rule)
        #expect(try JSONDecoder().decode(RecurrenceRule.self, from: data).frequencyValue == .daily)
    }

    @Test("RecurrenceRule bilinmeyen sıklık çözülür ama frequencyValue nil döner")
    func recurrenceUnknownFrequency() throws {
        let json = Data(#"{"frequency":"monthly","weekdays":[]}"#.utf8)
        let rule = try JSONDecoder().decode(RecurrenceRule.self, from: json)
        #expect(rule.frequency == "monthly")
        #expect(rule.frequencyValue == nil)
    }
}

// MARK: - Enum raw value'ları (docs/ARCHITECTURE.md 4.3; TS ile aynı kalmalı)

@Suite("Enum raw value'ları")
struct EnumRawValueTests {
    @Test("YksField") func yksField() { expectRawValues(YksField.self, ["SAY", "EA", "SOZ", "DIL"]) }
    @Test("ExamType") func examType() { expectRawValues(ExamType.self, ["TYT", "AYT", "YDT"]) }
    @Test("BookKind") func bookKind() {
        expectRawValues(BookKind.self, ["lecture", "questionBank", "practiceExam", "other"])
    }
    @Test("BookUnit") func bookUnit() { expectRawValues(BookUnit.self, ["page", "test", "section"]) }
    @Test("FocusSegmentKind") func focusSegmentKind() {
        expectRawValues(FocusSegmentKind.self, ["focus", "break"])
    }
    @Test("TaskKind") func taskKind() { expectRawValues(TaskKind.self, ["routine", "assignment"]) }
    @Test("RecurrenceFrequency") func recurrenceFrequency() {
        expectRawValues(RecurrenceFrequency.self, ["daily", "weekly"])
    }
    @Test("FriendStatus") func friendStatus() {
        expectRawValues(FriendStatus.self, ["pending", "accepted", "blocked"])
    }

    @Test("YksField kullanıcıya görünen adlar")
    func yksFieldLabels() {
        #expect(YksField.allCases.map(\.shortLabel) == ["SAY", "EA", "SÖZ", "DİL"])
        #expect(YksField.allCases.map(\.label) == ["Sayısal", "Eşit Ağırlık", "Sözel", "Dil"])
        #expect(YksField.allCases.allSatisfy { !$0.summary.isEmpty })
    }

    private func expectRawValues<E: CaseIterable & RawRepresentable>(
        _ type: E.Type, _ expected: [String]
    ) where E.RawValue == String {
        #expect(E.allCases.map(\.rawValue) == expected)
        // Her raw value'dan geri dönüşüm (CloudKit'ten gelen string'ler).
        #expect(expected.compactMap { E(rawValue: $0) }.count == expected.count)
    }
}
