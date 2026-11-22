import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct ReminderSchedulerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 10))! }

    private struct Fixture {
        let context: ModelContext
        let service: MockNotificationService
        let scheduler: ReminderScheduler
        let preferences: ReminderPreferences
    }

    private func make(
        authorization: NotificationAuthorization = .authorized, settings: ReminderSettings
    ) throws -> Fixture {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        try ProfileRepository(context: context).completeOnboarding(field: .say, appleUserId: nil, displayName: nil)
        let defaults = UserDefaults(suiteName: "reminder-scheduler-\(UUID().uuidString)")!
        let preferences = ReminderPreferences(defaults: defaults)
        preferences.save(settings)
        let service = MockNotificationService(authorization: authorization)
        return Fixture(
            context: context, service: service,
            scheduler: ReminderScheduler(service: service, preferences: preferences), preferences: preferences)
    }

    private let studyOnly = ReminderSettings(studyEnabled: true, studyTime: ReminderTime(hour: 19))

    @Test func schedulesStudyRemindersWithGoalText() async throws {
        let fixture = try make(settings: studyOnly)
        try ProfileRepository(context: fixture.context).setDailyFocusGoal(minutes: 180)
        let plan = await fixture.scheduler.reschedule(context: fixture.context, now: now, calendar: calendar)
        #expect(plan.count == 7)
        #expect(plan.first?.body == "Bugünkü hedefin: 3 saat")
        #expect(fixture.service.scheduled == plan)
    }

    @Test func cancelsTodayWhenGoalReachedBySessions() async throws {
        let fixture = try make(settings: studyOnly)
        try ProfileRepository(context: fixture.context).setDailyFocusGoal(minutes: 60)
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 7))!
        let focus = FocusRepository(context: fixture.context)
        let session = try focus.start(now: start)
        _ = try focus.finish(sessionId: session.id, now: start.addingTimeInterval(61 * 60))
        let plan = await fixture.scheduler.reschedule(context: fixture.context, now: now, calendar: calendar)
        #expect(plan.contains { $0.id == "fokus.reminder.study.2026-11-22" } == false)
        #expect(plan.count == 6)
    }

    @Test func routineReminderCountsRoutinesScheduledThatDay() async throws {
        let fixture = try make(settings: ReminderSettings(routineEnabled: true, routineTime: ReminderTime(hour: 8)))
        let tasks = TasksRepository(context: fixture.context)
        _ = try tasks.create(
            TaskValues(kind: .routine, title: "Paragraf", recurrence: RecurrenceRule(frequency: .daily)),
            today: "2026-11-01", now: now)
        let plan = await fixture.scheduler.reschedule(context: fixture.context, now: now, calendar: calendar)
        #expect(plan.map(\.body).allSatisfy { $0 == "Bugün 1 rutinin var." })
        #expect(plan.count == 6)  // bugün 08:00 geçmiş
    }

    @Test func deniedPermissionSchedulesNothingAndClears() async throws {
        let fixture = try make(authorization: .denied, settings: studyOnly)
        let plan = await fixture.scheduler.reschedule(context: fixture.context, now: now, calendar: calendar)
        #expect(plan.isEmpty && fixture.service.scheduled.isEmpty)
    }

    @Test func allDisabledClearsPendingReminders() async throws {
        let fixture = try make(settings: ReminderSettings())
        _ = await fixture.service.requestAuthorization()
        await fixture.service.replaceReminders(with: [
            PlannedReminder(id: "x", kind: .study, day: "2026-11-23", time: .studyDefault, title: "t", body: "b")
        ])
        await fixture.scheduler.cancelAll()
        #expect(fixture.service.scheduled.isEmpty)
    }

    @Test func preferencesPersistAndReset() throws {
        let fixture = try make(settings: studyOnly)
        #expect(fixture.preferences.load() == studyOnly)
        fixture.preferences.reset()
        #expect(fixture.preferences.load() == ReminderSettings())
    }

    @Test func mockServiceRequestAuthorizationFlow() async {
        let granting = MockNotificationService()
        #expect(await granting.requestAuthorization())
        #expect(await granting.authorizationStatus() == .authorized)
        let denying = MockNotificationService(grantsOnRequest: false)
        #expect(await denying.requestAuthorization() == false)
        #expect(await denying.authorizationStatus() == .denied)
    }
}
