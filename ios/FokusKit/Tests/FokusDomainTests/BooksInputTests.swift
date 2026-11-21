import Testing

@testable import FokusDomain

// Kitap form girdileri — web `progressInput.ts` ve `ProgressSheet.progressWarnings` vakaları.

@Suite("BooksInput")
struct BooksInputTests {
    struct ReachedCase: Sendable {
        let name: String
        let raw: String
        let expected: Int?
    }

    static let reachedCases: [ReachedCase] = [
        ReachedCase(name: "normal sayı", raw: "34", expected: 34),
        ReachedCase(name: "sıfır geçerli", raw: "0", expected: 0),
        ReachedCase(name: "boşluklar kırpılır", raw: "  12 ", expected: 12),
        ReachedCase(name: "boş → nil", raw: "", expected: nil),
        ReachedCase(name: "yalnız boşluk → nil", raw: "   ", expected: nil),
        ReachedCase(name: "ondalıklı → nil", raw: "3.5", expected: nil),
        ReachedCase(name: "virgüllü → nil", raw: "3,5", expected: nil),
        ReachedCase(name: "negatif → nil", raw: "-4", expected: nil),
        ReachedCase(name: "harf → nil", raw: "12a", expected: nil),
        ReachedCase(name: "Arapça-Hint rakamı → nil", raw: "٣٤", expected: nil),
        ReachedCase(name: "taşan sayı → nil", raw: "99999999999999999999999", expected: nil),
    ]

    @Test("parseReachedUnit", arguments: reachedCases)
    func parseReached(_ testCase: ReachedCase) {
        #expect(BooksInput.parseReachedUnit(testCase.raw) == testCase.expected)
    }

    struct TotalCase: Sendable {
        let name: String
        let raw: String
        let expected: BooksInput.TotalInput
    }

    static let totalCases: [TotalCase] = [
        TotalCase(name: "boş → bilinmiyor", raw: "", expected: .unknown),
        TotalCase(name: "boşluk → bilinmiyor", raw: "  ", expected: .unknown),
        TotalCase(name: "pozitif → değer", raw: "120", expected: .value(120)),
        TotalCase(name: "0 → geçersiz", raw: "0", expected: .invalid),
        TotalCase(name: "negatif → geçersiz", raw: "-5", expected: .invalid),
        TotalCase(name: "ondalık → geçersiz", raw: "2.5", expected: .invalid),
        TotalCase(name: "harf → geçersiz", raw: "abc", expected: .invalid),
    ]

    @Test("parseTotal", arguments: totalCases)
    func parseTotal(_ testCase: TotalCase) {
        #expect(BooksInput.parseTotal(testCase.raw) == testCase.expected)
    }

    struct WarningCase: Sendable {
        let name: String
        let value: Int?
        let current: Int
        let total: Int?
        let expected: [BooksInput.ProgressWarning]
    }

    static let warningCases: [WarningCase] = [
        WarningCase(name: "geçersiz girdi → uyarı yok", value: nil, current: 10, total: 100, expected: []),
        WarningCase(name: "ileri gidiş → uyarı yok", value: 50, current: 10, total: 100, expected: []),
        WarningCase(name: "aynı konum → uyarı yok", value: 10, current: 10, total: 100, expected: []),
        WarningCase(name: "geride → düzeltme", value: 5, current: 10, total: 100, expected: [.behindPrevious]),
        WarningCase(name: "toplama ulaştı → tamamlandı", value: 100, current: 10, total: 100, expected: [.completesBook]),
        WarningCase(name: "toplamı aştı → tamamlandı", value: 130, current: 10, total: 100, expected: [.completesBook]),
        WarningCase(name: "toplam bilinmiyor → tamamlandı yok", value: 500, current: 10, total: nil, expected: []),
        WarningCase(name: "toplam 0 → tamamlandı yok", value: 5, current: 0, total: 0, expected: []),
        WarningCase(
            name: "geride ve toplamda (ör. 120→100/100)", value: 100, current: 120, total: 100,
            expected: [.behindPrevious, .completesBook]),
    ]

    @Test("progressWarnings", arguments: warningCases)
    func warnings(_ testCase: WarningCase) {
        let result = BooksInput.progressWarnings(
            value: testCase.value, currentReached: testCase.current, total: testCase.total)
        #expect(result == testCase.expected)
    }

    @Test("uyarı metinleri Türkçe ve boş değil")
    func warningMessages() {
        #expect(BooksInput.ProgressWarning.behindPrevious.message.contains("düzeltme"))
        #expect(BooksInput.ProgressWarning.completesBook.message.contains("tamamlandı"))
    }
}
