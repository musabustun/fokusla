import Foundation
import Testing

@testable import FokusDomain

// Saat istatistik ekranı. Sabit saat dilimi ve `now`; `Date()` yok.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()
/// 2027-01-15 14:00 İstanbul.
private let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 14))!
private func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

private struct Fixture {
    var sessions: [FocusSessionSnapshot] = []
    var segments: [FocusSegmentSnapshot] = []

    /// `start` saat önce başlayıp `minutes` dakika odak, bitmiş oturum.
    @discardableResult
    mutating func finished(start: Double, minutes: Double, deleted: Bool = false) -> UUID {
        let id = UUID()
        let begin = hoursAgo(start)
        let end = begin.addingTimeInterval(minutes * 60)
        sessions.append(
            FocusSessionSnapshot(id: id, startedAt: begin, endedAt: end, deletedAt: deleted ? end : nil))
        segments.append(
            FocusSegmentSnapshot(
                id: UUID(), sessionId: id, kind: .focus, startedAt: begin, endedAt: end, deletedAt: nil))
        return id
    }
}

@Suite("WatchStatsCalc")
struct WatchStatsCalcTests {
    @Test("boş depo: 7 sıfır gün, son oturum yok, hedef oranı hedefe göre")
    func empty() {
        let summary = WatchStatsCalc.summary(
            sessions: [], segments: [], subjectIds: [:], goalMinutes: 120, now: now, calendar: calendar)
        #expect(summary.week.count == 7)
        #expect(summary.week.last?.day == "2027-01-15" && summary.week.first?.day == "2027-01-09")
        #expect(summary.todayMs == 0 && summary.weekMaxMs == 0 && summary.weekTotalMs == 0)
        #expect(summary.recent.isEmpty)
        #expect(summary.goalRatio == 0)
    }

    @Test("bugün, dün ve 8 gün önce: hafta penceresi, son oturumlar en yeni önce, ders kimliği taşınır")
    func weekAndRecent() {
        var fixture = Fixture()
        let subject = UUID()
        let today = fixture.finished(start: 3, minutes: 60)
        let yesterday = fixture.finished(start: 24, minutes: 30)
        fixture.finished(start: 8 * 24, minutes: 45)
        fixture.finished(start: 2, minutes: 15, deleted: true)
        let summary = WatchStatsCalc.summary(
            sessions: fixture.sessions, segments: fixture.segments, subjectIds: [today: subject],
            goalMinutes: 120, now: now, calendar: calendar)
        #expect(summary.todayMs == 60 * 60_000)
        #expect(summary.week[5].focusMs == 30 * 60_000)
        #expect(summary.weekTotalMs == 90 * 60_000)
        #expect(summary.weekMaxMs == 60 * 60_000)
        #expect(summary.goalRatio == 0.5)
        #expect(summary.recent.map(\.id).prefix(2) == [today, yesterday])
        #expect(summary.recent.count == 3)
        #expect(summary.recent[0].subjectId == subject && summary.recent[1].subjectId == nil)
    }

    @Test("hedef kapalı/0 → oran nil; hedef aşılınca oran 1")
    func goal() {
        var fixture = Fixture()
        fixture.finished(start: 5, minutes: 200)
        let off = WatchStatsCalc.summary(
            sessions: fixture.sessions, segments: fixture.segments, subjectIds: [:], goalMinutes: 0, now: now,
            calendar: calendar)
        #expect(off.goalMinutes == nil && off.goalRatio == nil)
        let over = WatchStatsCalc.summary(
            sessions: fixture.sessions, segments: fixture.segments, subjectIds: [:], goalMinutes: 120, now: now,
            calendar: calendar)
        #expect(over.goalRatio == 1)
    }

    @Test("son oturumlar en çok 5")
    func recentLimit() {
        var fixture = Fixture()
        for index in 0..<7 { fixture.finished(start: Double(index) + 1, minutes: 10) }
        let summary = WatchStatsCalc.summary(
            sessions: fixture.sessions, segments: fixture.segments, subjectIds: [:], goalMinutes: nil, now: now,
            calendar: calendar)
        #expect(summary.recent.count == WatchStatsCalc.recentLimit)
    }
}

@Suite("FocusLink tercih hedefi")
struct FocusLinkGoalPreferenceTests {
    @Test("nil → dokunma, 0 → kapat, n → n dakika; JSON'da korunur")
    func goalUpdate() throws {
        #expect(FocusLink.Preferences(palette: nil).goalUpdate == nil)
        #expect(FocusLink.Preferences(palette: nil, dailyGoalMinutes: 0).goalUpdate == .some(nil))
        #expect(FocusLink.Preferences(palette: nil, dailyGoalMinutes: 90).goalUpdate == .some(90))
        let preferences = FocusLink.Preferences(palette: "mono", dailyGoalMinutes: 90)
        #expect(FocusLink.preferences(from: try #require(FocusLink.payload(preferences))) == preferences)
    }
}
