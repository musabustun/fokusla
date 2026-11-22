import Foundation
import Testing

@testable import FokusDomain

// Live Activity durum hesabı testleri. Saat dilimi Europe/Istanbul'a, `now` sabittir; `Date()` yok.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

private let now = local(2026, 11, 19, 14)

private let testNamespace = UUID(uuidString: "5d0e7c1a-3b94-4f6e-8a21-9c7d4e6b1f30")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

private func session(
    _ name: String, start: Date, end: Date? = nil, deleted: Date? = nil
) -> FocusSessionSnapshot {
    FocusSessionSnapshot(id: uuid(name), startedAt: start, endedAt: end, deletedAt: deleted)
}

private func segment(
    _ name: String, session sessionName: String?, _ kind: FocusSegmentKind, start: Date, end: Date? = nil,
    deleted: Date? = nil
) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: uuid(name), sessionId: sessionName.map(uuid), kind: kind, startedAt: start, endedAt: end,
        deletedAt: deleted)
}

private let minute: TimeInterval = 60

struct FocusActivityCalcTests {
    // MARK: - Etkinlik yok

    @Test func noSessionsMeansNoActivity() {
        #expect(FocusActivityCalc.state(sessions: [], segments: [], now: now) == nil)
    }

    @Test func endedSessionMeansNoActivity() {
        let sessions = [session("s", start: local(2026, 11, 19, 10), end: local(2026, 11, 19, 11))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 10), end: local(2026, 11, 19, 11))]
        #expect(FocusActivityCalc.state(sessions: sessions, segments: segments, now: now) == nil)
    }

    @Test func deletedOpenSessionMeansNoActivity() {
        let sessions = [session("s", start: local(2026, 11, 19, 13), deleted: local(2026, 11, 19, 13, 30))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 13))]
        #expect(FocusActivityCalc.state(sessions: sessions, segments: segments, now: now) == nil)
    }

    // MARK: - Odak fazı

    @Test func focusTimerStartIsNowMinusClosedAndOpenFocusExcludingBreaks() {
        let sessions = [session("s", start: local(2026, 11, 19, 12))]
        let segments = [
            segment("f1", session: "s", .focus, start: local(2026, 11, 19, 12), end: local(2026, 11, 19, 12, 10)),
            segment("b1", session: "s", .break, start: local(2026, 11, 19, 12, 10), end: local(2026, 11, 19, 12, 15)),
            // Açık odak: 13:57 → 14:00 = 3 dk.
            segment("f2", session: "s", .focus, start: local(2026, 11, 19, 13, 57)),
        ]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state?.phase == .focus)
        #expect(state?.timerStart == now.addingTimeInterval(-13 * minute))
    }

    @Test func focusWithOnlyOpenSegment() {
        let sessions = [session("s", start: local(2026, 11, 19, 13))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 13))]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state == FocusActivityCalc.State(phase: .focus, timerStart: local(2026, 11, 19, 13)))
    }

    @Test func focusIgnoresDeletedSegmentsAndOtherSessions() {
        let sessions = [session("s", start: local(2026, 11, 19, 13)), session("other", start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 10))]
        let segments = [
            segment("f", session: "s", .focus, start: local(2026, 11, 19, 13, 30)),
            segment("deleted", session: "s", .focus, start: local(2026, 11, 19, 13), end: local(2026, 11, 19, 13, 20), deleted: local(2026, 11, 19, 13, 25)),
            segment("foreign", session: "other", .focus, start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 10)),
            segment("orphan", session: nil, .focus, start: local(2026, 11, 19, 8), end: local(2026, 11, 19, 9)),
        ]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state?.phase == .focus)
        #expect(state?.timerStart == now.addingTimeInterval(-30 * minute))
    }

    @Test func focusTimerStartStaysStableAsNowAdvances() throws {
        let sessions = [session("s", start: local(2026, 11, 19, 13))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 13))]
        let first = try #require(FocusActivityCalc.state(sessions: sessions, segments: segments, now: now))
        let later = try #require(
            FocusActivityCalc.state(sessions: sessions, segments: segments, now: now.addingTimeInterval(10 * minute)))
        #expect(first == later)
    }

    // MARK: - Mola fazı

    @Test func breakTimerStartIsOpenBreakStart() {
        let sessions = [session("s", start: local(2026, 11, 19, 12))]
        let segments = [
            segment("f", session: "s", .focus, start: local(2026, 11, 19, 12), end: local(2026, 11, 19, 13, 30)),
            segment("b", session: "s", .break, start: local(2026, 11, 19, 13, 30)),
        ]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state == FocusActivityCalc.State(phase: .break, timerStart: local(2026, 11, 19, 13, 30)))
    }

    @Test func openSessionWithoutOpenSegmentIsTreatedAsBreakStartingNow() {
        let sessions = [session("s", start: local(2026, 11, 19, 12))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 12), end: local(2026, 11, 19, 13))]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state == FocusActivityCalc.State(phase: .break, timerStart: now))
    }

    @Test func openSessionWithNoSegmentsAtAllIsBreakStartingNow() {
        let sessions = [session("s", start: local(2026, 11, 19, 12))]
        let state = FocusActivityCalc.state(sessions: sessions, segments: [], now: now)
        #expect(state == FocusActivityCalc.State(phase: .break, timerStart: now))
    }

    // MARK: - Birden fazla açık oturum

    @Test func latestStartedOpenSessionWins() {
        let sessions = [
            session("old", start: local(2026, 11, 19, 10)),
            session("new", start: local(2026, 11, 19, 12)),
        ]
        let segments = [
            segment("oldFocus", session: "old", .focus, start: local(2026, 11, 19, 10)),
            segment("newBreak", session: "new", .break, start: local(2026, 11, 19, 13, 40)),
        ]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state == FocusActivityCalc.State(phase: .break, timerStart: local(2026, 11, 19, 13, 40)))
    }

    @Test func latestStartedWinsRegardlessOfListOrder() {
        let sessions = [
            session("new", start: local(2026, 11, 19, 12)),
            session("old", start: local(2026, 11, 19, 10)),
        ]
        let segments = [
            segment("newFocus", session: "new", .focus, start: local(2026, 11, 19, 13, 50)),
            segment("oldBreak", session: "old", .break, start: local(2026, 11, 19, 13)),
        ]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state?.phase == .focus)
        #expect(state?.timerStart == now.addingTimeInterval(-10 * minute))
    }

    @Test func endedAndDeletedSessionsDoNotCompeteWithOpenOne() {
        let sessions = [
            session("open", start: local(2026, 11, 19, 9)),
            session("endedLater", start: local(2026, 11, 19, 12), end: local(2026, 11, 19, 13)),
            session("deletedLater", start: local(2026, 11, 19, 13), deleted: local(2026, 11, 19, 13, 10)),
        ]
        let segments = [segment("f", session: "open", .focus, start: local(2026, 11, 19, 13, 45))]
        let state = FocusActivityCalc.state(sessions: sessions, segments: segments, now: now)
        #expect(state?.phase == .focus)
        #expect(state?.timerStart == now.addingTimeInterval(-15 * minute))
    }
}

struct FocusActivityEquivalenceTests {
    struct Case: Sendable {
        let name: String
        let otherPhase: FocusActivityCalc.Phase
        let offset: TimeInterval
        let expected: Bool
    }

    private static let base = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [
        Case(name: "aynı an", otherPhase: .focus, offset: 0, expected: true),
        Case(name: "1 sn sonra", otherPhase: .focus, offset: 1, expected: true),
        Case(name: "tam 1.5 sn sonra (sınır dahil)", otherPhase: .focus, offset: 1.5, expected: true),
        Case(name: "tam 1.5 sn önce (sınır dahil)", otherPhase: .focus, offset: -1.5, expected: true),
        Case(name: "1.6 sn sonra", otherPhase: .focus, offset: 1.6, expected: false),
        Case(name: "1.6 sn önce", otherPhase: .focus, offset: -1.6, expected: false),
        Case(name: "1 dk sonra", otherPhase: .focus, offset: 60, expected: false),
        Case(name: "faz farklı, aynı an", otherPhase: .break, offset: 0, expected: false),
        Case(name: "faz farklı, tolerans içi", otherPhase: .break, offset: 1, expected: false),
    ])
    func equivalenceUsesPhaseAndDefaultTolerance(testCase: Case) {
        let lhs = FocusActivityCalc.State(phase: .focus, timerStart: Self.base)
        let rhs = FocusActivityCalc.State(
            phase: testCase.otherPhase, timerStart: Self.base.addingTimeInterval(testCase.offset))
        #expect(lhs.isEquivalent(to: rhs) == testCase.expected, Comment(rawValue: testCase.name))
        // Simetrik olmalı.
        #expect(rhs.isEquivalent(to: lhs) == testCase.expected, Comment(rawValue: testCase.name))
    }

    @Test func customToleranceIsRespected() {
        let lhs = FocusActivityCalc.State(phase: .break, timerStart: Self.base)
        let rhs = FocusActivityCalc.State(phase: .break, timerStart: Self.base.addingTimeInterval(5))
        #expect(lhs.isEquivalent(to: rhs) == false)
        #expect(lhs.isEquivalent(to: rhs, tolerance: 5))
        #expect(lhs.isEquivalent(to: rhs, tolerance: 4.9) == false)
    }

    @Test func stateRoundTripsThroughCodable() throws {
        let state = FocusActivityCalc.State(phase: .break, timerStart: Self.base)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(FocusActivityCalc.State.self, from: data)
        #expect(decoded == state)
    }
}
