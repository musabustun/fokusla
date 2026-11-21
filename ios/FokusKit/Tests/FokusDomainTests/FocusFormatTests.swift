import Testing

@testable import FokusDomain

// Süre biçimleri — web `formatDuration.test.ts` vakalarıyla birebir.

private let second: Double = 1000
private let minute: Double = 60 * second
private let hour: Double = 60 * minute

private struct FormatCase: Sendable, CustomTestStringConvertible {
    let ms: Double
    let expected: String
    var testDescription: String { "\(ms) ms → \(expected)" }
}

private func formatCase(_ ms: Double, _ expected: String) -> FormatCase {
    FormatCase(ms: ms, expected: expected)
}

private let clockCases: [FormatCase] = [
    formatCase(0, "00:00"),
    formatCase(999, "00:00"),
    formatCase(second, "00:01"),
    formatCase(5 * minute + 9 * second, "05:09"),
    formatCase(5 * minute + 9 * second + 999, "05:09"),
    formatCase(59 * minute + 59 * second, "59:59"),
    formatCase(hour, "1:00:00"),
    formatCase(hour + 5 * minute + 9 * second, "1:05:09"),
    formatCase(12 * hour + 34 * minute + 56 * second, "12:34:56"),
    formatCase(-5 * second, "00:00"),
    formatCase(Double.nan, "00:00"),
]

private let durationCases: [FormatCase] = [
    formatCase(0, "0 sn"),
    formatCase(45 * second, "45 sn"),
    formatCase(59 * second + 999, "59 sn"),
    formatCase(minute, "1 dk"),
    formatCase(25 * minute, "25 dk"),
    formatCase(25 * minute + 59 * second, "25 dk"),
    formatCase(59 * minute + 59 * second, "59 dk"),
    formatCase(hour, "1 sa"),
    formatCase(hour + 5 * minute, "1 sa 5 dk"),
    formatCase(hour + 5 * minute + 30 * second, "1 sa 5 dk"),
    formatCase(26 * hour, "26 sa"),
    formatCase(-minute, "0 sn"),
    formatCase(Double.infinity, "0 sn"),
]

@Suite("FocusFormat")
struct FocusFormatTests {
    @Test("clock", arguments: clockCases)
    fileprivate func clock(_ testCase: FormatCase) {
        #expect(FocusFormat.clock(testCase.ms) == testCase.expected)
    }

    @Test("durationText", arguments: durationCases)
    fileprivate func durationText(_ testCase: FormatCase) {
        #expect(FocusFormat.durationText(testCase.ms) == testCase.expected)
    }

    @Test func durationPartsSplitValueAndUnit() {
        #expect(
            FocusFormat.durationParts(hour + 5 * minute)
                == [.init(value: 1, unit: "sa"), .init(value: 5, unit: "dk")])
        #expect(FocusFormat.durationParts(45 * second) == [.init(value: 45, unit: "sn")])
    }

    @Test func hugeValuesDoNotOverflow() {
        #expect(!FocusFormat.clock(Double.greatestFiniteMagnitude).isEmpty)
    }
}
