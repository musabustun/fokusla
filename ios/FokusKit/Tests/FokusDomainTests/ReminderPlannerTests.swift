import Foundation
import Testing

@testable import FokusDomain

struct ReminderPlannerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    /// 2026-11-22 (Pazar) 10:00 yerel.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 10))!
    }

    private let both = ReminderSettings(
        routineEnabled: true, routineTime: ReminderTime(hour: 8), studyEnabled: true, studyTime: ReminderTime(hour: 19, minute: 30))

    private func counts(_ value: Int, from: ISODate = "2026-11-22", days: Int = 7) -> [ISODate: Int] {
        Dictionary(uniqueKeysWithValues: (0..<days).map { (TasksCalc.addDays(from, $0), value) })
    }

    private func plan(
        _ settings: ReminderSettings, goal: Int? = 180, focusMs: Double = 0,
        routineCounts: [ISODate: Int]? = nil, now: Date? = nil, horizon: Int = 7
    ) -> [PlannedReminder] {
        ReminderPlanner.plan(
            settings: settings, now: now ?? self.now, calendar: calendar, goalMinutes: goal,
            focusMsToday: focusMs, routineCounts: routineCounts ?? counts(2), horizonDays: horizon)
    }

    @Test func nothingWhenAllDisabled() {
        #expect(plan(ReminderSettings()).isEmpty)
    }

    @Test func skipsPastTimesToday() {
        // Saat 10:00: bugünkü 08:00 rutin geçmiş, 19:30 çalışma gelecek.
        let result = plan(both, horizon: 1)
        #expect(result.map(\.id) == ["fokus.reminder.study.2026-11-22"])
    }

    @Test func plansSevenDaysWithRoutineAndStudy() {
        let result = plan(both)
        // Bugün: yalnızca çalışma; diğer 6 gün: rutin + çalışma.
        #expect(result.count == 1 + 6 * 2)
        #expect(result.first?.kind == .study)
        #expect(result[1].id == "fokus.reminder.routine.2026-11-23")
        #expect(result[2].id == "fokus.reminder.study.2026-11-23")
        #expect(result.last?.day == "2026-11-28")
    }

    @Test func routineBodyCarriesCountPerDay() {
        let result = plan(
            ReminderSettings(routineEnabled: true),
            routineCounts: ["2026-11-23": 3, "2026-11-24": 1, "2026-11-25": 0])
        #expect(result.map(\.id) == ["fokus.reminder.routine.2026-11-23", "fokus.reminder.routine.2026-11-24"])
        #expect(result.map(\.body) == ["Bugün 3 rutinin var.", "Bugün 1 rutinin var."])
    }

    @Test func studyBodyUsesGoal() {
        let withGoal = plan(ReminderSettings(studyEnabled: true), goal: 210, horizon: 1)
        #expect(withGoal.first?.body == "Bugünkü hedefin: 3 saat 30 dk")
        let noGoal = plan(ReminderSettings(studyEnabled: true), goal: nil, horizon: 1)
        #expect(noGoal.first?.body == "Bir odak oturumu başlatmaya ne dersin?")
    }

    @Test func goalReachedCancelsOnlyTodaysStudyReminder() {
        let result = plan(ReminderSettings(studyEnabled: true), goal: 120, focusMs: 120 * 60_000)
        #expect(result.contains { $0.id == "fokus.reminder.study.2026-11-22" } == false)
        #expect(result.contains { $0.id == "fokus.reminder.study.2026-11-23" })
        #expect(result.count == 6)
    }

    @Test func goalNotReachedKeepsTodaysStudyReminder() {
        let result = plan(ReminderSettings(studyEnabled: true), goal: 120, focusMs: 119 * 60_000, horizon: 1)
        #expect(result.count == 1)
    }

    @Test func reminderExactlyAtNowIsNotScheduled() {
        let settings = ReminderSettings(studyEnabled: true, studyTime: ReminderTime(hour: 10))
        #expect(plan(settings, horizon: 1).isEmpty)
        let later = ReminderSettings(studyEnabled: true, studyTime: ReminderTime(hour: 10, minute: 1))
        #expect(plan(later, horizon: 1).count == 1)
    }

    @Test func zeroHorizonPlansNothing() {
        #expect(plan(both, horizon: 0).isEmpty)
    }

    @Test func routineCountsExcludeCompletedTodayAndCountScheduledLater() {
        let routine = TaskSnapshot(
            id: UUID(), title: "Paragraf", kind: .routine,
            recurrence: RecurrenceRule(frequency: .daily), startDate: "2026-11-01", createdAt: now)
        let done = TaskCompletionSnapshot(id: UUID(), taskId: routine.id, date: "2026-11-22", completedAt: now)
        let days = ["2026-11-22", "2026-11-23"]
        let open = ReminderPlanner.routineCounts(
            tasks: [routine], completions: [], days: days, today: "2026-11-22", calendar: calendar)
        #expect(open == ["2026-11-22": 1, "2026-11-23": 1])
        let afterDone = ReminderPlanner.routineCounts(
            tasks: [routine], completions: [done], days: days, today: "2026-11-22", calendar: calendar)
        #expect(afterDone == ["2026-11-22": 0, "2026-11-23": 1])
    }

    @Test func reminderTimeClampsAndFormats() {
        #expect(ReminderTime(hour: 25, minute: -3) == ReminderTime(hour: 23, minute: 0))
        #expect(ReminderTime(hour: 8, minute: 5).text == "08:05")
        #expect(ReminderTime(minutesSinceMidnight: 19 * 60 + 30) == ReminderTime(hour: 19, minute: 30))
        #expect(ReminderTime(minutesSinceMidnight: 99_999) == ReminderTime(hour: 23, minute: 59))
    }

    @Test func settingsRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(both)
        #expect(try JSONDecoder().decode(ReminderSettings.self, from: data) == both)
    }
}
