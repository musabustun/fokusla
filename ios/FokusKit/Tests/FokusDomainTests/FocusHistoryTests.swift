import Foundation
import Testing

@testable import FokusDomain

// Geçmiş oturum listesi (web `features/focus/history.ts` → `buildHistoryRows` mantığı).

private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let minute: TimeInterval = 60

private func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * minute) }

private func session(
    _ n: Int, start: Double, end: Double? = nil, deleted: Bool = false
) -> FocusSessionSnapshot {
    FocusSessionSnapshot(
        id: id(n), startedAt: at(start), endedAt: end.map(at), deletedAt: deleted ? at(0) : nil)
}

private func id(_ n: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
}

private func focus(
    _ n: Int, session sessionNo: Int, start: Double, end: Double?, kind: FocusSegmentKind = .focus
) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: id(100 + n), sessionId: id(sessionNo), kind: kind, startedAt: at(start), endedAt: end.map(at))
}

@Suite("FocusCalc.historyEntries")
struct FocusHistoryTests {
    private let now = at(1000)

    @Test func onlyFinishedSessionsNewestFirst() {
        let sessions = [
            session(1, start: 0, end: 30),
            session(2, start: 100, end: 160),
            session(3, start: 200),  // açık oturum: geçmişte yok
        ]
        let segments = [
            focus(1, session: 1, start: 0, end: 30),
            focus(2, session: 2, start: 100, end: 140),
            focus(3, session: 2, start: 140, end: 150, kind: .break),
            focus(4, session: 2, start: 150, end: 160),
            focus(5, session: 3, start: 200, end: nil),
        ]
        let entries = FocusCalc.historyEntries(sessions: sessions, segments: segments, now: now)
        #expect(entries.map(\.id) == [id(2), id(1)])
        // Mola sayılmaz: 40 + 10 dk odak.
        #expect(entries.map(\.focusMs) == [50 * minute * 1000, 30 * minute * 1000])
    }

    @Test func deletedSessionsAndSegmentsAreIgnored() {
        let sessions = [session(1, start: 0, end: 30, deleted: true), session(2, start: 40, end: 70)]
        var gone = focus(2, session: 2, start: 60, end: 70)
        gone.deletedAt = at(80)
        let segments = [focus(1, session: 1, start: 0, end: 30), focus(3, session: 2, start: 40, end: 60), gone]
        let entries = FocusCalc.historyEntries(sessions: sessions, segments: segments, now: now)
        #expect(entries.map(\.id) == [id(2)])
        #expect(entries.first?.focusMs == 20 * minute * 1000)
    }

    @Test func limitKeepsMostRecent() {
        let sessions = (1...5).map { session($0, start: Double($0) * 10, end: Double($0) * 10 + 5) }
        let entries = FocusCalc.historyEntries(sessions: sessions, segments: [], now: now, limit: 2)
        #expect(entries.map(\.id) == [id(5), id(4)])
        #expect(FocusCalc.historyEntries(sessions: sessions, segments: [], now: now, limit: 0).isEmpty)
    }

    @Test func tiesKeepInputOrderAndSessionWithoutSegmentsHasZeroFocus() {
        let sessions = [session(1, start: 10, end: 20), session(2, start: 10, end: 20)]
        let entries = FocusCalc.historyEntries(sessions: sessions, segments: [], now: now)
        #expect(entries.map(\.id) == [id(1), id(2)])
        #expect(entries.allSatisfy { $0.focusMs == 0 })
    }

    @Test func emptyInputGivesEmptyList() {
        #expect(FocusCalc.historyEntries(sessions: [], segments: [], now: now).isEmpty)
    }
}
