import FokusDomain
import Foundation
import SwiftData

/// Hatırlatmaları verideki güncel duruma göre (hedef, bugünkü odak, rutinler) yeniden planlar.
/// Uygulama açılışında/öne gelişinde ve ilgili veri ya da tercih değiştiğinde çağrılır.
@MainActor
public struct ReminderScheduler {
    private let service: any NotificationService
    private let preferences: ReminderPreferences

    public init(service: any NotificationService, preferences: ReminderPreferences = ReminderPreferences()) {
        self.service = service
        self.preferences = preferences
    }

    /// Planı hesaplar ve sisteme yazar. İzin yoksa ya da hiçbir hatırlatma açık değilse bekleyenleri siler.
    /// - Returns: sisteme yazılan hatırlatmalar.
    @discardableResult
    public func reschedule(
        context: ModelContext, now: Date = .now, calendar: Calendar = .current
    ) async -> [PlannedReminder] {
        let settings = preferences.load()
        guard settings.isAnyEnabled, await service.authorizationStatus().canSchedule else {
            await service.replaceReminders(with: [])
            return []
        }
        let plan = (try? makePlan(settings: settings, context: context, now: now, calendar: calendar)) ?? []
        await service.replaceReminders(with: plan)
        return plan
    }

    /// Tüm bekleyen hatırlatmaları siler (tüm veriyi silme, çıkış vb.).
    public func cancelAll() async {
        await service.replaceReminders(with: [])
    }

    func makePlan(
        settings: ReminderSettings, context: ModelContext, now: Date, calendar: Calendar
    ) throws -> [PlannedReminder] {
        let today = Identifiers.isoDate(now, calendar: calendar)
        let days = (0..<ReminderPlanner.horizonDays).map { TasksCalc.addDays(today, $0) }

        let goal = try ProfileRepository(context: context).current()?.dailyFocusGoalMinutes
        let sessions = EntityStore<FocusSession>(context: context)
        let segments = EntityStore<FocusSegment>(context: context)
        let focusMs = try FocusCalc.dailyFocusTotalMs(
            sessions: try sessions.all().map(\.snapshot), segments: try segments.all().map(\.snapshot),
            day: today, now: now, calendar: calendar)

        let tasks = try EntityStore<StudyTask>(context: context).all().map(\.snapshot)
        let completions = try EntityStore<TaskCompletion>(context: context).all().map(\.snapshot)
        let counts = ReminderPlanner.routineCounts(
            tasks: tasks, completions: completions, days: days, today: today, calendar: calendar)

        return ReminderPlanner.plan(
            settings: settings, now: now, calendar: calendar, goalMinutes: goal,
            focusMsToday: focusMs, routineCounts: counts)
    }
}
