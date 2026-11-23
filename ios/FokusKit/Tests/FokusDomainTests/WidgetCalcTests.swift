import Foundation
import Testing

@testable import FokusDomain

// Widget hesapları testleri (odak özeti, timeline planı, bugünün görevleri).
// Saat dilimi Europe/Istanbul'a, `now` sabittir; `Date()` çağrılmaz.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

private let now = local(2026, 11, 19, 14)
private let minute: TimeInterval = 60
private let minuteMs = 60_000.0

private let testNamespace = UUID(uuidString: "7a3f9d12-6e45-4c8b-b1d0-2f5e8a9c3b64")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

private func session(_ name: String, start: Date, end: Date? = nil, deleted: Date? = nil) -> FocusSessionSnapshot {
    FocusSessionSnapshot(id: uuid(name), startedAt: start, endedAt: end, deletedAt: deleted)
}

private func segment(
    _ name: String, session sessionName: String, _ kind: FocusSegmentKind, start: Date, end: Date? = nil,
    deleted: Date? = nil
) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: uuid(name), sessionId: uuid(sessionName), kind: kind, startedAt: start, endedAt: end,
        deletedAt: deleted)
}

// MARK: - focusSummary

struct WidgetFocusSummaryTests {
    private func summary(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], goalMinutes: Int? = nil,
        at date: Date = now
    ) -> WidgetCalc.FocusSummary {
        WidgetCalc.focusSummary(
            sessions: sessions, segments: segments, goalMinutes: goalMinutes, now: date, calendar: calendar)
    }

    @Test func emptyData() {
        let result = summary(sessions: [], segments: [])
        #expect(result == WidgetCalc.FocusSummary(focusMs: 0, isRunning: false, goal: nil, timerStart: nil))
        #expect(result.ratio == 0)
    }

    @Test func emptyDataWithGoalHasZeroRatioButGoalPresent() throws {
        let result = summary(sessions: [], segments: [], goalMinutes: 120)
        let goal = try #require(result.goal)
        #expect(goal.goalMinutes == 120)
        #expect(goal.remainingMs == 120 * minuteMs)
        #expect(result.ratio == 0)
        #expect(result.isRunning == false)
    }

    @Test func sumsClosedFocusSegmentsAndIgnoresBreaks() {
        let sessions = [session("s", start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 11))]
        let segments = [
            segment("f1", session: "s", .focus, start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 9, 30)),
            segment("b", session: "s", .break, start: local(2026, 11, 19, 9, 30), end: local(2026, 11, 19, 10)),
            segment("f2", session: "s", .focus, start: local(2026, 11, 19, 10), end: local(2026, 11, 19, 10, 15)),
        ]
        let result = summary(sessions: sessions, segments: segments, goalMinutes: 60)
        #expect(result.focusMs == 45 * minuteMs)
        #expect(result.isRunning == false)
        #expect(result.timerStart == nil)
        #expect(result.ratio == 0.75)
        #expect(result.goal?.remainingMs == 15 * minuteMs)
    }

    @Test func ignoresPreviousDaysDeletedSegmentsAndDeletedSessions() {
        let sessions = [
            session("s", start: local(2026, 11, 18, 9), end: local(2026, 11, 19, 12)),
            session("gone", start: local(2026, 11, 19, 8), end: local(2026, 11, 19, 9), deleted: local(2026, 11, 19, 9, 5)),
        ]
        let segments = [
            segment("yesterday", session: "s", .focus, start: local(2026, 11, 18, 9), end: local(2026, 11, 18, 10)),
            segment("today", session: "s", .focus, start: local(2026, 11, 19, 10), end: local(2026, 11, 19, 10, 20)),
            segment("deletedSegment", session: "s", .focus, start: local(2026, 11, 19, 11), end: local(2026, 11, 19, 11, 30), deleted: local(2026, 11, 19, 11, 31)),
            segment("deletedSession", session: "gone", .focus, start: local(2026, 11, 19, 8), end: local(2026, 11, 19, 9)),
        ]
        #expect(summary(sessions: sessions, segments: segments).focusMs == 20 * minuteMs)
    }

    @Test func segmentCrossingMidnightIsSplitToToday() {
        let sessions = [session("s", start: local(2026, 11, 18, 23, 30), end: local(2026, 11, 19, 0, 30))]
        let segments = [
            segment("f", session: "s", .focus, start: local(2026, 11, 18, 23, 30), end: local(2026, 11, 19, 0, 30))
        ]
        // Yalnızca gece yarısından sonraki 30 dk bugüne yazılır.
        #expect(summary(sessions: sessions, segments: segments).focusMs == 30 * minuteMs)
    }

    @Test func runningFocusIsRunningWithTimerStartAtNowMinusFocus() {
        let sessions = [
            session("done", start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 10)),
            session("live", start: local(2026, 11, 19, 13)),
        ]
        let segments = [
            segment("f1", session: "done", .focus, start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 9, 30)),
            segment("f2", session: "live", .focus, start: local(2026, 11, 19, 13)),
        ]
        let result = summary(sessions: sessions, segments: segments, goalMinutes: 180)
        #expect(result.focusMs == 90 * minuteMs)
        #expect(result.isRunning)
        #expect(result.timerStart == now.addingTimeInterval(-90 * minute))
        #expect(result.ratio == 0.5)
    }

    @Test func runningFocusAcrossMidnightCountsOnlyTodayPart() {
        let late = local(2026, 11, 19, 0, 30)
        let sessions = [session("live", start: local(2026, 11, 18, 23))]
        let segments = [segment("f", session: "live", .focus, start: local(2026, 11, 18, 23))]
        let result = summary(sessions: sessions, segments: segments, at: late)
        #expect(result.focusMs == 30 * minuteMs)
        #expect(result.isRunning)
        #expect(result.timerStart == late.addingTimeInterval(-30 * minute))
    }

    @Test func onBreakIsNotRunningAndHasNoTimerStart() {
        let sessions = [session("live", start: local(2026, 11, 19, 10))]
        let segments = [
            segment("f", session: "live", .focus, start: local(2026, 11, 19, 10), end: local(2026, 11, 19, 11)),
            segment("b", session: "live", .break, start: local(2026, 11, 19, 13, 30)),
        ]
        let result = summary(sessions: sessions, segments: segments)
        #expect(result.focusMs == 60 * minuteMs)
        #expect(result.isRunning == false)
        #expect(result.timerStart == nil)
    }

    @Test func noGoalMeansNilGoalAndZeroRatio() {
        let sessions = [session("s", start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 10))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 9), end: local(2026, 11, 19, 10))]
        let result = summary(sessions: sessions, segments: segments, goalMinutes: nil)
        #expect(result.focusMs == 60 * minuteMs)
        #expect(result.goal == nil)
        #expect(result.ratio == 0)
    }

    @Test func goalExceededCapsRatioAtOne() throws {
        let sessions = [session("s", start: local(2026, 11, 19, 8), end: local(2026, 11, 19, 10))]
        let segments = [segment("f", session: "s", .focus, start: local(2026, 11, 19, 8), end: local(2026, 11, 19, 10))]
        let result = summary(sessions: sessions, segments: segments, goalMinutes: 60)
        let goal = try #require(result.goal)
        #expect(result.focusMs == 120 * minuteMs)
        #expect(result.ratio == 1)
        #expect(goal.isReached)
        #expect(goal.remainingMs == 0)
    }

    @Test func invalidGoalIsTreatedAsNoGoal() {
        #expect(summary(sessions: [], segments: [], goalMinutes: 0).goal == nil)
        #expect(summary(sessions: [], segments: [], goalMinutes: -10).goal == nil)
    }
}

// MARK: - timelinePlan / nextMidnight

struct WidgetTimelineTests {
    private static let midnight = local(2026, 11, 20, 0)

    @Test func stationaryHasSingleEntryAndReloadsAtNextMidnight() {
        let plan = WidgetCalc.timelinePlan(isRunning: false, now: now, calendar: calendar)
        #expect(plan.entries == [now])
        #expect(plan.reloadAfter == Self.midnight)
    }

    @Test func runningHasTwelveEntriesFiveMinutesApart() {
        let plan = WidgetCalc.timelinePlan(isRunning: true, now: now, calendar: calendar)
        #expect(plan.entries.count == WidgetCalc.runningEntryCount)
        #expect(plan.entries.count == 12)
        #expect(plan.entries.first == now)
        for (index, entry) in plan.entries.enumerated() {
            #expect(entry == now.addingTimeInterval(Double(index) * 5 * minute))
            #expect(entry < Self.midnight)
        }
        // Son girdi 14:55; bir adım sonrası 15:00.
        #expect(plan.reloadAfter == now.addingTimeInterval(60 * minute))
    }

    @Test func runningNearMidnightTrimsEntriesAndReloadsAtMidnight() {
        let late = local(2026, 11, 19, 23, 42)
        let plan = WidgetCalc.timelinePlan(isRunning: true, now: late, calendar: calendar)
        // 23:42, 23:47, 23:52, 23:57 — 00:02 ve sonrası kırpılır.
        #expect(plan.entries == [0, 5, 10, 15].map { late.addingTimeInterval(Double($0) * minute) })
        #expect(plan.entries.allSatisfy { $0 < Self.midnight })
        #expect(plan.reloadAfter <= Self.midnight)
        #expect(plan.reloadAfter == Self.midnight)
    }

    @Test func runningInLastSecondKeepsOnlyNow() {
        let last = local(2026, 11, 19, 23, 59, 59)
        let plan = WidgetCalc.timelinePlan(isRunning: true, now: last, calendar: calendar)
        #expect(plan.entries == [last])
        #expect(plan.reloadAfter == Self.midnight)
    }

    @Test func runningRightAfterMidnightKeepsAllEntries() {
        let start = local(2026, 11, 19, 0)
        let plan = WidgetCalc.timelinePlan(isRunning: true, now: start, calendar: calendar)
        #expect(plan.entries.count == 12)
        #expect(plan.entries.first == start)
        #expect(plan.reloadAfter == start.addingTimeInterval(60 * minute))
    }

    @Test func entriesAreStrictlyIncreasing() {
        let plan = WidgetCalc.timelinePlan(isRunning: true, now: now, calendar: calendar)
        #expect(plan.entries == plan.entries.sorted())
        #expect(Set(plan.entries).count == plan.entries.count)
    }

    struct MidnightCase: Sendable {
        let name: String
        let from: Date
        let expected: Date
    }

    @Test(arguments: [
        MidnightCase(name: "öğleden sonra", from: local(2026, 11, 19, 14), expected: local(2026, 11, 20, 0)),
        MidnightCase(name: "tam gece yarısı sonraki gün sayılır", from: local(2026, 11, 19, 0), expected: local(2026, 11, 20, 0)),
        MidnightCase(name: "gün sonu saniye", from: local(2026, 11, 19, 23, 59, 59), expected: local(2026, 11, 20, 0)),
        MidnightCase(name: "ay sonu", from: local(2026, 11, 30, 10), expected: local(2026, 12, 1, 0)),
        MidnightCase(name: "yıl sonu", from: local(2026, 12, 31, 22), expected: local(2027, 1, 1, 0)),
    ])
    func nextMidnight(testCase: MidnightCase) {
        #expect(
            WidgetCalc.nextMidnight(after: testCase.from, calendar: calendar) == testCase.expected,
            Comment(rawValue: testCase.name))
    }

    @Test func nextMidnightIsDSTSafeOnTwentyFiveHourDay() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        // 2026-10-25: saatler geri alınır (25 saatlik gün).
        let from = berlin.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        let expected = berlin.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 0))!
        #expect(WidgetCalc.nextMidnight(after: from, calendar: berlin) == expected)
    }
}

// MARK: - todayTasks

struct WidgetTodayTasksTests {
    private static let routine = RecurrenceRule(frequency: .daily)

    private func task(
        _ title: String, kind: TaskKind = .assignment, order: Int = 0, due: ISODate? = nil,
        completedAt: Date? = nil, recurrence: RecurrenceRule? = nil, deletedAt: Date? = nil,
        subjectId: UUID? = nil
    ) -> TaskSnapshot {
        TaskSnapshot(
            id: uuid(title), title: title, kind: kind, order: order, dueDate: due, recurrence: recurrence,
            completedAt: completedAt, startDate: nil, createdAt: local(2026, 11, 1), deletedAt: deletedAt,
            subjectId: subjectId)
    }

    private func routine(_ title: String, order: Int = 0) -> TaskSnapshot {
        task(title, kind: .routine, order: order, recurrence: Self.routine)
    }

    private func completion(_ title: String, on day: ISODate = "2026-11-19") -> TaskCompletionSnapshot {
        TaskCompletionSnapshot(
            id: uuid("completion-\(title)-\(day)"), taskId: uuid(title), date: day,
            completedAt: local(2026, 11, 19, 9))
    }

    private func list(
        _ tasks: [TaskSnapshot], completions: [TaskCompletionSnapshot] = [], subjectNames: [UUID: String] = [:]
    ) -> WidgetCalc.TaskList {
        WidgetCalc.todayTasks(
            tasks: tasks, completions: completions, subjectNames: subjectNames, now: now, calendar: calendar)
    }

    @Test func emptyList() {
        let result = list([])
        #expect(result.items.isEmpty)
        #expect(result.done == 0)
        #expect(result.total == 0)
        #expect(result.next == nil)
        #expect(result.isComplete == false)
    }

    @Test func includesRoutinesOverdueAndDueTodayButNotUpcoming() {
        let tasks = [
            routine("Kitap oku"),
            task("Bugün ödev", due: "2026-11-19"),
            task("Geciken ödev", due: "2026-11-17"),
            task("Yaklaşan ödev", due: "2026-11-21"),
        ]
        let result = list(tasks)
        #expect(result.items.map(\.title) == ["Kitap oku", "Geciken ödev", "Bugün ödev"])
        #expect(result.total == 3)
        #expect(result.done == 0)
        #expect(result.items.contains { $0.title == "Yaklaşan ödev" } == false)
    }

    @Test func excludesDeletedTasksUnscheduledRoutinesAndAssignmentsFinishedEarlier() {
        let tasks = [
            routine("Aktif rutin"),
            task("Silinmiş", due: "2026-11-19", deletedAt: local(2026, 11, 18)),
            // 2026-11-19 Perşembe (ISO 4); yalnızca Pazartesi planlı.
            task("Pazartesi rutini", kind: .routine, recurrence: RecurrenceRule(frequency: .weekly, weekdays: [1])),
            task("Dünkü bitmiş", due: "2026-11-18", completedAt: local(2026, 11, 18, 10)),
        ]
        #expect(list(tasks).items.map(\.title) == ["Aktif rutin"])
    }

    @Test func openItemsComeFirstKeepingOrderThenCompletedKeepingOrder() {
        let tasks = [
            routine("Kitap oku", order: 0),
            routine("Su iç", order: 1),
            routine("Spor", order: 2),
            task("Geciken ödev", due: "2026-11-17"),
            task("Bugün ödev", due: "2026-11-19", completedAt: local(2026, 11, 19, 10)),
        ]
        let result = list(tasks, completions: [completion("Su iç")])
        #expect(result.items.map(\.title) == ["Kitap oku", "Spor", "Geciken ödev", "Su iç", "Bugün ödev"])
        #expect(result.items.map(\.isDone) == [false, false, false, true, true])
        #expect(result.done == 2)
        #expect(result.total == 5)
        #expect(result.isComplete == false)
    }

    @Test func routineCompletionOnAnotherDayDoesNotCount() {
        let result = list([routine("Kitap oku")], completions: [completion("Kitap oku", on: "2026-11-18")])
        #expect(result.done == 0)
        #expect(result.items.first?.isDone == false)
    }

    @Test func allDoneIsComplete() {
        let result = list([routine("Kitap oku")], completions: [completion("Kitap oku")])
        #expect(result.done == 1)
        #expect(result.total == 1)
        #expect(result.isComplete)
        #expect(result.next == nil)
    }

    @Test func mapsSubjectNameAndDueTexts() {
        let subjectId = uuid("matematik")
        let tasks = [
            task("Geciken ödev", due: "2026-11-17", subjectId: subjectId),
            task("Bugün ödev", due: "2026-11-19"),
            routine("Kitap oku"),
        ]
        let result = list(tasks, subjectNames: [subjectId: "Matematik"])
        let byTitle = Dictionary(uniqueKeysWithValues: result.items.map { ($0.title, $0) })

        #expect(byTitle["Geciken ödev"]?.subjectName == "Matematik")
        #expect(byTitle["Geciken ödev"]?.dueText == "2 gün gecikti")
        #expect(byTitle["Geciken ödev"]?.isOverdue == true)
        #expect(byTitle["Bugün ödev"]?.dueText == "Bugün")
        #expect(byTitle["Bugün ödev"]?.isOverdue == false)
        #expect(byTitle["Bugün ödev"]?.subjectName == nil)
        #expect(byTitle["Kitap oku"]?.dueText == nil)
        #expect(byTitle["Kitap oku"]?.isOverdue == false)
        #expect(result.items.allSatisfy { $0.canToggle })
    }

    @Test func nextIsFirstOpenItem() {
        let tasks = [routine("Kitap oku", order: 0), routine("Su iç", order: 1), routine("Spor", order: 2)]
        let result = list(tasks, completions: [completion("Kitap oku")])
        #expect(result.next?.title == "Su iç")
    }

    // `next` yalnızca açık VE işaretlenebilir görevi verir (TaskItem iç başlatıcısı @testable ile erişilir).
    private func item(_ title: String, done: Bool, canToggle: Bool) -> WidgetCalc.TaskItem {
        WidgetCalc.TaskItem(
            id: uuid(title), title: title, isDone: done, canToggle: canToggle, subjectName: nil, dueText: nil,
            isOverdue: false)
    }

    @Test func nextSkipsDoneAndNonToggleableItems() {
        let items = [
            item("Bitti", done: true, canToggle: true),
            item("Planlı değil", done: false, canToggle: false),
            item("Sıradaki", done: false, canToggle: true),
            item("Sonraki", done: false, canToggle: true),
        ]
        let result = WidgetCalc.TaskList(items: items, done: 1, total: 4)
        #expect(result.next?.title == "Sıradaki")
    }

    @Test func nextIsNilWhenNothingIsOpenAndToggleable() {
        let items = [item("Bitti", done: true, canToggle: true), item("Kilitli", done: false, canToggle: false)]
        #expect(WidgetCalc.TaskList(items: items, done: 1, total: 2).next == nil)
    }

    @Test func isCompleteRequiresAtLeastOneTask() {
        #expect(WidgetCalc.TaskList(items: [], done: 0, total: 0).isComplete == false)
        #expect(WidgetCalc.TaskList(items: [], done: 2, total: 3).isComplete == false)
        #expect(WidgetCalc.TaskList(items: [], done: 3, total: 3).isComplete)
    }
}

// MARK: - StandBy görünüm modeli

@Suite struct WidgetStandByTests {
    private func focus(
        ms: Double, running: Bool = false, goalMinutes: Int? = nil
    ) -> WidgetCalc.FocusSummary {
        WidgetCalc.FocusSummary(
            focusMs: ms, isRunning: running,
            goal: DailyGoalCalc.progress(focusMs: ms, goalMinutes: goalMinutes),
            timerStart: running ? now.addingTimeInterval(-ms / 1000) : nil)
    }

    @Test func runningShowsStatusAndSubject() {
        let display = WidgetCalc.standBy(focus: focus(ms: 30 * minuteMs, running: true, goalMinutes: 60), subject: "TYT Türkçe")
        #expect(display.statusText == "Odak sürüyor")
        #expect(display.titleText == "TYT Türkçe")
        #expect(display.isRunning)
        #expect(display.ratio == 0.5)
        #expect(display.goalText == "30 dk kaldı")
        #expect(display.percentText == "%50")
    }

    @Test func runningWithoutSubjectIsFreeStudy() {
        let display = WidgetCalc.standBy(focus: focus(ms: 0, running: true), subject: nil)
        #expect(display.titleText == "Serbest çalışma")
        #expect(display.goalText == nil)
        #expect(display.percentText == nil)
    }

    @Test func blankSubjectIsTreatedAsMissing() {
        let display = WidgetCalc.standBy(focus: focus(ms: 0, running: true), subject: "   ")
        #expect(display.titleText == "Serbest çalışma")
    }

    @Test func idleShowsTodayAndRemaining() {
        let display = WidgetCalc.standBy(focus: focus(ms: 15 * minuteMs, goalMinutes: 60), subject: "Yok sayılır")
        #expect(display.statusText == "Bugün")
        #expect(display.titleText == nil)
        #expect(!display.isRunning)
        #expect(display.goalText == "45 dk kaldı")
    }

    @Test func idleWithoutGoalHasNoGoalLine() {
        let display = WidgetCalc.standBy(focus: focus(ms: 15 * minuteMs), subject: nil)
        #expect(display.goalText == nil)
        #expect(display.ratio == 0)
        #expect(!display.isGoalReached)
    }

    @Test func reachedGoalIsExplicitInText() {
        let display = WidgetCalc.standBy(focus: focus(ms: 90 * minuteMs, goalMinutes: 60), subject: nil)
        #expect(display.isGoalReached)
        #expect(display.goalText == "Hedef tamam")
        #expect(display.ratio == 1)
        #expect(display.percentText == "%100")
    }

    @Test func timerStartIsPassedThroughOnlyWhileRunning() {
        #expect(WidgetCalc.standBy(focus: focus(ms: 60_000, running: true), subject: nil).timerStart != nil)
        #expect(WidgetCalc.standBy(focus: focus(ms: 60_000), subject: nil).timerStart == nil)
    }

    @Test func accessibilitySummaryIsPlainSentence() {
        let running = WidgetCalc.standBy(focus: focus(ms: 75 * minuteMs, running: true, goalMinutes: 120), subject: "AYT Matematik")
        #expect(running.accessibilityText == "Odak sürüyor, AYT Matematik, 1 sa 15 dk, 45 dk kaldı")
        let idle = WidgetCalc.standBy(focus: focus(ms: 75 * minuteMs), subject: nil)
        #expect(idle.accessibilityText == "Bugün, 1 sa 15 dk")
    }

    @Test func dateLineIsTurkishDayTitle() {
        #expect(WidgetCalc.standByDateLine(now, calendar: calendar) == "19 Kasım Perşembe")
    }
}

// MARK: - "Odak saati" timeline

@Suite struct ClockTimelineTests {
    @Test func firstEntryIsCurrentMinuteStart() {
        let plan = WidgetCalc.clockTimelinePlan(now: local(2026, 11, 19, 14, 7, 42), calendar: calendar)
        #expect(plan.entries.first == local(2026, 11, 19, 14, 7, 0))
    }

    @Test func entriesAreOneMinuteApartAndMinuteAligned() {
        let plan = WidgetCalc.clockTimelinePlan(now: local(2026, 11, 19, 14, 7, 42), calendar: calendar)
        #expect(plan.entries.count == WidgetCalc.clockEntryCount)
        for (a, b) in zip(plan.entries, plan.entries.dropFirst()) { #expect(b.timeIntervalSince(a) == 60) }
        #expect(plan.entries.allSatisfy { calendar.component(.second, from: $0) == 0 })
        #expect(plan.reloadAfter == local(2026, 11, 19, 16, 7, 0))
    }

    @Test func exactMinuteBoundaryKeepsThatMinute() {
        let plan = WidgetCalc.clockTimelinePlan(now: local(2026, 11, 19, 9, 30, 0), calendar: calendar)
        #expect(plan.entries.first == local(2026, 11, 19, 9, 30, 0))
    }

    @Test func entriesStopAtMidnightAndReloadThere() {
        let plan = WidgetCalc.clockTimelinePlan(now: local(2026, 11, 19, 23, 40, 10), calendar: calendar)
        #expect(plan.entries.count == 20)
        #expect(plan.entries.last == local(2026, 11, 19, 23, 59, 0))
        #expect(plan.reloadAfter == local(2026, 11, 20, 0, 0, 0))
    }
}
