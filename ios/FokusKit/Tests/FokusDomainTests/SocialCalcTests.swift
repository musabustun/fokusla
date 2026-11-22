import Foundation
import Testing

@testable import FokusDomain

// Sosyal hesaplar — web `social.test.ts` vakalarıyla birebir (aynı vaka adları).
// Saat dilimi sabit (UTC) takvimle verilir; testler cihazın saat diliminden bağımsızdır.

private let second: Double = 1000
private let minute: Double = 60 * second

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

private func at(_ hour: Int, _ minute: Int = 0, day: Int = 19) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))
        ?? Date(timeIntervalSince1970: 0)
}

private let now = at(10, 0)
private func ago(_ ms: Double) -> Date { now.addingTimeInterval(-ms / 1000) }

// MARK: - validateUsername

private struct UsernameCase: Sendable, CustomTestStringConvertible {
    let name: String
    let raw: String
    let expected: UsernameValidation
    var testDescription: String { "\(name): \(raw.debugDescription)" }
}

private func valid(_ name: String, _ raw: String, _ username: String) -> UsernameCase {
    UsernameCase(name: name, raw: raw, expected: .valid(username))
}

private func invalid(_ name: String, _ raw: String, _ problem: UsernameProblem) -> UsernameCase {
    UsernameCase(name: name, raw: raw, expected: .invalid(problem))
}

private let usernameCases: [UsernameCase] = [
    valid("plain lowercase", "musab", "musab"),
    valid("leading @ dropped", "@musab", "musab"),
    valid("surrounding whitespace trimmed", "  musab  ", "musab"),
    valid("whitespace trimmed before @ is dropped", "  @musab ", "musab"),
    valid("ASCII uppercase lowercased", "MuSaB", "musab"),
    valid("Turkish İ lowercased to i (tr-TR)", "ALİ", "ali"),
    valid("digits, dot and underscore allowed", "ali.veli_42", "ali.veli_42"),
    valid("exactly 3 characters", "abc", "abc"),
    valid("exactly 20 characters", String(repeating: "a", count: 20), String(repeating: "a", count: 20)),
    valid("@ does not count toward length", "@abc", "abc"),
    invalid("2 characters", "ab", .tooShort),
    invalid("empty", "", .tooShort),
    invalid("only whitespace", "   ", .tooShort),
    invalid("only @", "@", .tooShort),
    invalid("@ + 2 characters", "@ab", .tooShort),
    invalid("21 characters", String(repeating: "a", count: 21), .tooLong),
    invalid("ASCII I lowercased to dotless ı (tr-TR) → invalid", "ALI", .invalidChars),
    invalid("Turkish letters", "şükrü", .invalidChars),
    invalid("dotless ı", "alı", .invalidChars),
    invalid("inner space", "ali veli", .invalidChars),
    invalid("hyphen", "ali-veli", .invalidChars),
    invalid("only one leading @ dropped", "@@ali", .invalidChars),
    invalid("@ in the middle", "ali@veli", .invalidChars),
    invalid("starts with digit", "1ali", .mustStartWithLetter),
    invalid("starts with dot", ".ali", .mustStartWithLetter),
    invalid("starts with underscore", "_ali", .mustStartWithLetter),
    // Öncelik: uzunluk → karakter → ilk harf.
    invalid("too short wins over invalid chars", "ş", .tooShort),
    invalid("too short wins over first-letter", "1a", .tooShort),
    invalid("too long wins over invalid chars", String(repeating: "ş", count: 21), .tooLong),
    invalid("invalid chars wins over first-letter", "1alı", .invalidChars),
]

// MARK: - normalizeInviteCode

private struct InviteCase: Sendable, CustomTestStringConvertible {
    let name: String
    let raw: String
    let expected: String?
    var testDescription: String { "\(name): \(raw.debugDescription) → \(expected ?? "nil")" }
}

private let inviteCases: [InviteCase] = [
    InviteCase(name: "already normalized", raw: "AB12CD", expected: "AB12CD"),
    InviteCase(name: "lowercase is uppercased", raw: "ab12cd", expected: "AB12CD"),
    InviteCase(name: "dash separated", raw: "AB1-2CD", expected: "AB12CD"),
    InviteCase(name: "spaces anywhere", raw: " ab 12 cd ", expected: "AB12CD"),
    InviteCase(name: "dashes and spaces mixed", raw: "a-b 1-2 c-d", expected: "AB12CD"),
    InviteCase(name: "tab and newline removed", raw: "AB1\t2C\nD", expected: "AB12CD"),
    InviteCase(name: "all digits", raw: "123456", expected: "123456"),
    InviteCase(name: "dotless ı uppercases to I", raw: "abcdeı", expected: "ABCDEI"),
    InviteCase(name: "5 characters", raw: "AB12C", expected: nil),
    InviteCase(name: "7 characters", raw: "AB12CDE", expected: nil),
    InviteCase(name: "empty", raw: "", expected: nil),
    InviteCase(name: "only separators", raw: " - - ", expected: nil),
    InviteCase(name: "Turkish letter", raw: "AB12CŞ", expected: nil),
    InviteCase(name: "dotted İ", raw: "AB12Cİ", expected: nil),
    InviteCase(name: "punctuation", raw: "AB12C!", expected: nil),
    InviteCase(name: "underscore", raw: "AB_2CD", expected: nil),
]

// MARK: - Canlı durum

private func presence(
    state: PresenceState = .focusing,
    sessionStartedAt: Date? = ago(30 * minute),
    stateSince: Date? = ago(5 * minute),
    todayFocusMs: Double = 60 * minute,
    updatedAt: Date = ago(minute)
) -> SocialPresence {
    SocialPresence(
        state: state, sessionStartedAt: sessionStartedAt, stateSince: stateSince,
        todayFocusMs: todayFocusMs, updatedAt: updatedAt)
}

private let fresh = ago(minute)
private let atThreshold = ago(SocialCalc.presenceStaleAfterMs)
private let justStale = ago(SocialCalc.presenceStaleAfterMs + 1)
private let future = now.addingTimeInterval(2 * 60)

private struct StateCase: Sendable, CustomTestStringConvertible {
    let name: String
    let input: SocialPresence?
    let expected: PresenceState
    var testDescription: String { name }
}

private let stateCases: [StateCase] = [
    StateCase(name: "null presence", input: nil, expected: .offline),
    StateCase(name: "fresh focusing", input: presence(state: .focusing, updatedAt: fresh), expected: .focusing),
    StateCase(name: "fresh onBreak", input: presence(state: .onBreak, updatedAt: fresh), expected: .onBreak),
    StateCase(name: "fresh offline", input: presence(state: .offline, updatedAt: fresh), expected: .offline),
    StateCase(name: "exactly at stale threshold", input: presence(updatedAt: atThreshold), expected: .focusing),
    StateCase(name: "1 ms past threshold", input: presence(updatedAt: justStale), expected: .offline),
    StateCase(name: "stale onBreak", input: presence(state: .onBreak, updatedAt: justStale), expected: .offline),
    StateCase(name: "updatedAt in the future (clock skew)", input: presence(updatedAt: future), expected: .focusing),
]

private struct MsCase: Sendable, CustomTestStringConvertible {
    let name: String
    let input: SocialPresence?
    let expected: Double
    var testDescription: String { name }
}

private let todayBase = 60 * minute

private let todayCases: [MsCase] = [
    MsCase(name: "null presence", input: nil, expected: 0),
    MsCase(name: "offline", input: presence(state: .offline, updatedAt: fresh), expected: todayBase),
    MsCase(name: "onBreak adds nothing", input: presence(state: .onBreak, updatedAt: fresh), expected: todayBase),
    MsCase(name: "focusing adds now − updatedAt", input: presence(updatedAt: fresh), expected: todayBase + minute),
    MsCase(
        name: "focusing exactly at threshold still adds", input: presence(updatedAt: atThreshold),
        expected: todayBase + SocialCalc.presenceStaleAfterMs),
    MsCase(name: "stale focusing adds nothing", input: presence(updatedAt: justStale), expected: todayBase),
    MsCase(name: "negative clock skew adds 0", input: presence(updatedAt: future), expected: todayBase),
    MsCase(name: "zero base while focusing", input: presence(todayFocusMs: 0, updatedAt: fresh), expected: minute),
]

private let sessionCases: [MsCase] = [
    MsCase(name: "null presence", input: nil, expected: 0),
    MsCase(name: "offline", input: presence(state: .offline, updatedAt: fresh), expected: 0),
    MsCase(name: "stale", input: presence(updatedAt: justStale), expected: 0),
    MsCase(name: "focusing", input: presence(sessionStartedAt: ago(30 * minute)), expected: 30 * minute),
    MsCase(
        name: "onBreak", input: presence(state: .onBreak, sessionStartedAt: ago(45 * minute)),
        expected: 45 * minute),
    MsCase(name: "sessionStartedAt null", input: presence(sessionStartedAt: nil), expected: 0),
    MsCase(name: "negative clock skew → 0", input: presence(sessionStartedAt: future), expected: 0),
]

private let stateMsCases: [MsCase] = [
    MsCase(name: "null presence", input: nil, expected: 0),
    MsCase(name: "offline", input: presence(state: .offline, updatedAt: fresh), expected: 0),
    MsCase(name: "stale", input: presence(updatedAt: justStale), expected: 0),
    MsCase(name: "focusing", input: presence(stateSince: ago(5 * minute)), expected: 5 * minute),
    MsCase(
        name: "onBreak", input: presence(state: .onBreak, stateSince: ago(2 * minute)),
        expected: 2 * minute),
    MsCase(name: "stateSince null", input: presence(stateSince: nil), expected: 0),
    MsCase(name: "negative clock skew → 0", input: presence(stateSince: future), expected: 0),
]

// MARK: - ownPresenceFromFocus

private let sessionActiveId = UUID()
private let sessionDoneId = UUID()
private let sessionNightId = UUID()
private let sessionOldId = UUID()
private let active = FocusSessionSnapshot(id: sessionActiveId, startedAt: at(9, 0))

private func segment(
    _ id: String, _ sessionId: UUID, _ kind: FocusSegmentKind, _ startedAt: Date, _ endedAt: Date?,
    deletedAt: Date? = nil
) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: segmentId(id), sessionId: sessionId, kind: kind, startedAt: startedAt, endedAt: endedAt,
        deletedAt: deletedAt)
}

/// Kısa ad → sabit UUID (aynı ad aynı id).
private func segmentId(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: Identifiers.catalogNamespace)
}

private struct OwnCase: Sendable, CustomTestStringConvertible {
    let name: String
    let activeSession: FocusSessionSnapshot?
    let segments: [FocusSegmentSnapshot]
    let expected: SocialPresence
    var testDescription: String { name }
}

private func expectedPresence(
    _ state: PresenceState, session: Date? = nil, since: Date? = nil, today: Double
) -> SocialPresence {
    SocialPresence(
        state: state, sessionStartedAt: session, stateSince: since, todayFocusMs: today, updatedAt: now)
}

private let ownCases: [OwnCase] = [
    OwnCase(
        name: "no active session, no segments → offline, 0", activeSession: nil, segments: [],
        expected: expectedPresence(.offline, today: 0)),
    OwnCase(
        name: "no active session still reports today total from finished sessions", activeSession: nil,
        segments: [
            segment("a", sessionDoneId, .focus, at(7, 0), at(7, 25)),
            segment("b", sessionDoneId, .break, at(7, 25), at(7, 30)),
            segment("c", sessionDoneId, .focus, at(7, 30), at(8, 0)),
        ],
        expected: expectedPresence(.offline, today: 55 * minute)),
    OwnCase(
        name: "open focus segment → focusing since its start; closed at now", activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 20)),
            segment("b", sessionActiveId, .break, at(9, 20), at(9, 30)),
            segment("c", sessionActiveId, .focus, at(9, 30), nil),
        ],
        expected: expectedPresence(.focusing, session: at(9, 0), since: at(9, 30), today: 50 * minute)),
    OwnCase(
        name: "open break segment → onBreak since its start", activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 40)),
            segment("b", sessionActiveId, .break, at(9, 40), nil),
        ],
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 40), today: 40 * minute)),
    OwnCase(
        name: "paused (no open segment) → onBreak since last segment end", activeSession: active,
        segments: [
            segment("b", sessionActiveId, .focus, at(9, 30), at(9, 45)),
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 20)),
        ],
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 45), today: 35 * minute)),
    OwnCase(
        name: "active session without segments → onBreak since session start", activeSession: active,
        segments: [segment("x", sessionDoneId, .focus, at(7, 0), at(7, 10))],
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 0), today: 10 * minute)),
    OwnCase(
        name: "segment crossing local midnight is clipped to today",
        activeSession: FocusSessionSnapshot(id: sessionNightId, startedAt: at(23, 0, day: 18)),
        segments: [segment("n", sessionNightId, .focus, at(23, 0, day: 18), nil)],
        expected: expectedPresence(
            .focusing, session: at(23, 0, day: 18), since: at(23, 0, day: 18), today: 10 * 60 * minute)),
    OwnCase(
        name: "closed segment entirely on the previous day counts 0", activeSession: nil,
        segments: [
            segment("y", sessionOldId, .focus, at(22, 0, day: 18), at(23, 0, day: 18)),
            segment("z", sessionOldId, .focus, at(23, 30, day: 18), at(0, 15)),
        ],
        expected: expectedPresence(.offline, today: 15 * minute)),
    OwnCase(
        name: "break segments never count toward today total", activeSession: nil,
        segments: [segment("b", sessionDoneId, .break, at(7, 0), at(8, 0))],
        expected: expectedPresence(.offline, today: 0)),
    OwnCase(
        name: "deleted segments are ignored (also for state)", activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 20)),
            segment("b", sessionActiveId, .focus, at(9, 20), nil, deletedAt: at(9, 25)),
        ],
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 20), today: 20 * minute)),
    OwnCase(
        name: "duplicate segment ids are counted once", activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 30)),
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 30)),
            segment("b", sessionActiveId, .focus, at(9, 40), nil),
            segment("b", sessionActiveId, .focus, at(9, 40), nil),
        ],
        expected: expectedPresence(.focusing, session: at(9, 0), since: at(9, 40), today: 50 * minute)),
    // Web'deki "most recently updated copy wins" vakası: snapshot'ta `updatedAt` yoktur; yerine
    // "ilk kopya kazanır" davranışı test edilir.
    OwnCase(
        name: "duplicate ids: the first copy wins", activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), at(9, 30)),
            segment("a", sessionActiveId, .focus, at(9, 0), nil),
        ],
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 30), today: 30 * minute)),
    OwnCase(
        name: "several open segments (inconsistent data): the latest started decides the state",
        activeSession: active,
        segments: [
            segment("a", sessionActiveId, .focus, at(9, 0), nil),
            segment("b", sessionActiveId, .break, at(9, 50), nil),
            segment("c", sessionActiveId, .focus, at(9, 10), nil),
        ],
        // Her açık odak segmenti now ile kapatılır: 60 + 50 dk.
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 50), today: 110 * minute)),
    OwnCase(
        name: "segments of other sessions do not decide the state", activeSession: active,
        segments: [
            segment("o", sessionDoneId, .focus, at(7, 0), nil),
            segment("a", sessionActiveId, .break, at(9, 50), nil),
        ],
        // Diğer oturumun açık segmenti de now ile kapatılmış sayılır: 07:00 → 10:00.
        expected: expectedPresence(.onBreak, session: at(9, 0), since: at(9, 50), today: 3 * 60 * minute)),
    OwnCase(
        name: "segment end after now (clock skew) is clipped to now", activeSession: nil,
        segments: [segment("f", sessionDoneId, .focus, at(9, 30), at(10, 30))],
        expected: expectedPresence(.offline, today: 30 * minute)),
]

@Suite("SocialCalc")
struct SocialCalcTests {
    @Test("constants: exposes the documented limits")
    func constants() {
        #expect(SocialCalc.usernameMinLength == 3)
        #expect(SocialCalc.usernameMaxLength == 20)
        #expect(SocialCalc.inviteCodeLength == 6)
        #expect(SocialCalc.presenceStaleAfterMs == 10 * minute)
    }

    @Test("validateUsername", arguments: usernameCases)
    fileprivate func validateUsername(_ testCase: UsernameCase) {
        #expect(SocialCalc.validateUsername(testCase.raw) == testCase.expected)
    }

    @Test("normalizeInviteCode", arguments: inviteCases)
    fileprivate func normalizeInviteCode(_ testCase: InviteCase) {
        #expect(SocialCalc.normalizeInviteCode(testCase.raw) == testCase.expected)
    }

    @Test("effectivePresenceState", arguments: stateCases)
    fileprivate func effectivePresenceState(_ testCase: StateCase) {
        #expect(SocialCalc.effectivePresenceState(testCase.input, now: now) == testCase.expected)
    }

    @Test("liveTodayFocusMs", arguments: todayCases)
    fileprivate func liveTodayFocusMs(_ testCase: MsCase) {
        #expect(SocialCalc.liveTodayFocusMs(testCase.input, now: now) == testCase.expected)
    }

    @Test("liveSessionMs", arguments: sessionCases)
    fileprivate func liveSessionMs(_ testCase: MsCase) {
        #expect(SocialCalc.liveSessionMs(testCase.input, now: now) == testCase.expected)
    }

    @Test("liveStateMs", arguments: stateMsCases)
    fileprivate func liveStateMs(_ testCase: MsCase) {
        #expect(SocialCalc.liveStateMs(testCase.input, now: now) == testCase.expected)
    }

    @Test("ownPresenceFromFocus", arguments: ownCases)
    fileprivate func ownPresenceFromFocus(_ testCase: OwnCase) {
        let result = SocialCalc.ownPresenceFromFocus(
            activeSession: testCase.activeSession, segments: testCase.segments, now: now,
            calendar: calendar)
        #expect(result == testCase.expected)
    }

    @Test("ownPresenceFromFocus: girdiyi değiştirmez ve saf kalır")
    func ownPresenceIsPure() {
        let segments = [segment("a", sessionActiveId, .focus, at(9, 0), nil)]
        let first = SocialCalc.ownPresenceFromFocus(
            activeSession: active, segments: segments, now: now, calendar: calendar)
        let second = SocialCalc.ownPresenceFromFocus(
            activeSession: active, segments: segments, now: now, calendar: calendar)
        #expect(first == second)
        #expect(segments == [segment("a", sessionActiveId, .focus, at(9, 0), nil)])
    }
}
