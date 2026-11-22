#if DEBUG
import FokusData
import FokusDomain
import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "debug-demo")

/// Yalnızca DEBUG: uygulama `-FokusDemoData` ile başlatılınca (onboarding tamamlandıysa) gerçek depoya örnek veri
/// ekler: günlük hedef, birkaç görev ve bugünkü iki odak oturumu. Widget / Live Activity ekran görüntüleri ve
/// mağaza materyalleri içindir (simülatörde metin yazılamadığı için). İdempotenttir: görev varsa dokunmaz.
enum DebugDemoData {
    static let launchArgument = "-FokusDemoData"

    @MainActor
    static func seedIfRequested(
        container: ModelContainer, arguments: [String] = ProcessInfo.processInfo.arguments, now: Date = .now
    ) {
        guard arguments.contains(launchArgument) else { return }
        let context = container.mainContext
        do {
            let profiles = ProfileRepository(context: context)
            guard try profiles.current() != nil else { return }
            let tasks = TasksRepository(context: context)
            guard try tasks.tasks().isEmpty else { return }

            try profiles.setDailyFocusGoal(minutes: 210, now: now)
            let today = Identifiers.isoDate(now)
            let daily = RecurrenceRule(frequency: .daily)
            let titles = ["Paragraf 20 soru", "Matematik limit tekrarı", "Kitap okuma 30 sayfa", "Deneme analizi"]
            var created: [StudyTask] = []
            for (index, title) in titles.enumerated() {
                let values =
                    index == 3
                    ? TaskValues(kind: .assignment, title: title, dueDate: today)
                    : TaskValues(kind: .routine, title: title, recurrence: daily)
                created.append(try tasks.create(values, today: today, now: now))
            }
            try tasks.toggleCompletion(created[2], on: today, now: now)

            let focus = FocusRepository(context: context)
            let first = now.addingTimeInterval(-3 * 3600)
            let second = now.addingTimeInterval(-90 * 60)
            let session1 = try focus.start(now: first)
            try focus.finish(sessionId: session1.id, now: first.addingTimeInterval(80 * 60))
            let session2 = try focus.start(now: second)
            try focus.finish(sessionId: session2.id, now: second.addingTimeInterval(45 * 60))
        } catch {
            logger.error("Demo verisi eklenemedi: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
