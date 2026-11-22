import Testing

@testable import FokusDomain

// Sosyal süre biçimleri — web `format.test.ts` vakalarıyla birebir.

private let minuteMs: Double = 60_000

private struct FormatCase: Sendable, CustomTestStringConvertible {
    let ms: Double
    let expected: String
    var testDescription: String { "\(ms) ms → \(expected)" }
}

private func formatCase(_ ms: Double, _ expected: String) -> FormatCase {
    FormatCase(ms: ms, expected: expected)
}

private let durationCases: [FormatCase] = [
    formatCase(0, "0 dk"),
    formatCase(1, "1 dk'dan az"),
    formatCase(59_999, "1 dk'dan az"),
    formatCase(-5, "0 dk"),
    formatCase(Double.nan, "0 dk"),
    formatCase(Double.infinity, "0 dk"),
    formatCase(minuteMs, "1 dk"),
    formatCase(25 * minuteMs + 59_000, "25 dk"),
    formatCase(60 * minuteMs, "1 sa 00 dk"),
    formatCase(130 * minuteMs, "2 sa 10 dk"),
]

private let clockCases: [FormatCase] = [
    formatCase(0, "00:00"),
    formatCase(-1000, "00:00"),
    formatCase(9_999, "00:09"),
    formatCase(4 * minuteMs + 9_000, "04:09"),
    formatCase(65 * minuteMs + 9_000, "1:05:09"),
    formatCase(Double.nan, "00:00"),
]

private let clockLabelCases: [FormatCase] = [
    formatCase(0, "0 saniye"),
    formatCase(65 * minuteMs + 9_000, "1 saat 5 dakika 9 saniye"),
    formatCase(2 * minuteMs, "2 dakika 0 saniye"),
]

@Suite("SocialFormat")
struct SocialFormatTests {
    @Test("formatDurationShort", arguments: durationCases)
    fileprivate func durationShort(_ testCase: FormatCase) {
        #expect(SocialFormat.formatDurationShort(testCase.ms) == testCase.expected)
    }

    @Test("formatDurationShort çok büyük değerde çökmez")
    func durationShortHuge() {
        #expect(!SocialFormat.formatDurationShort(Double.greatestFiniteMagnitude).isEmpty)
    }

    @Test("formatClock", arguments: clockCases)
    fileprivate func clock(_ testCase: FormatCase) {
        #expect(SocialFormat.formatClock(testCase.ms) == testCase.expected)
    }

    @Test("formatClock çok büyük değerde çökmez")
    func clockHuge() {
        #expect(!SocialFormat.formatClock(Double.greatestFiniteMagnitude).isEmpty)
        #expect(!SocialFormat.formatClockLabel(Double.greatestFiniteMagnitude).isEmpty)
    }

    @Test("formatClockLabel", arguments: clockLabelCases)
    fileprivate func clockLabel(_ testCase: FormatCase) {
        #expect(SocialFormat.formatClockLabel(testCase.ms) == testCase.expected)
    }

    @Test("formatPresenceLine: çevrimdışıda süre göstermez")
    func presenceLineOffline() {
        #expect(SocialFormat.formatPresenceLine(.offline, 10 * minuteMs) == "Çevrimdışı")
    }

    @Test("formatPresenceLine: odak ve molada süreyi ekler")
    func presenceLineOnline() {
        #expect(SocialFormat.formatPresenceLine(.focusing, 25 * minuteMs) == "Odakta · 25 dk")
        #expect(SocialFormat.formatPresenceLine(.onBreak, 4 * minuteMs) == "Molada · 4 dk")
    }

    @Test("presenceLabel", arguments: [
        (PresenceState.focusing, "Odakta"), (.onBreak, "Molada"), (.offline, "Çevrimdışı"),
    ])
    func presenceLabel(_ state: PresenceState, _ expected: String) {
        #expect(SocialFormat.presenceLabel(state) == expected)
    }

    @Test("inviteMessage: davet kodunu metne ekler")
    func inviteMessage() {
        #expect(SocialFormat.inviteMessage(code: "AB2CD3") == "Fokus'ta beni ekle: davet kodum AB2CD3")
    }
}
