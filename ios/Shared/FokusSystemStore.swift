import FokusData
import FokusDomain
import Foundation
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Uygulama, widget uzantısı ve App Intents'in ORTAK veri erişimi (`ios/Shared`, iki hedefe de derlenir).
///
/// - Uygulama sürecinde: `FokusApp` kendi container'ını `register` eder; intent'ler AYNI container'ı kullanır
///   (CloudKit deposunu ikinci kez açmayız).
/// - Uzantı sürecinde: App Group'taki depo dosyası VARSA CloudKit'siz (`.local`) açılır. Dosya yoksa
///   (uygulama henüz taşımadı) hata fırlatılır; uzantı ASLA boş depo oluşturmaz.
@MainActor
enum FokusSystem {
    enum StoreError: Error {
        case appGroupUnavailable
        case storeMissing
    }

    private static var registered: ModelContainer?
    private static var opened: ModelContainer?

    static func register(_ container: ModelContainer) { registered = container }

    static func container() throws -> ModelContainer {
        if let registered { return registered }
        if let opened { return opened }
        guard let group = FokusAppGroup.containerURL() else { throw StoreError.appGroupUnavailable }
        let url = FokusAppGroup.storeURL(in: group)
        guard FileManager.default.fileExists(atPath: url.path) else { throw StoreError.storeMissing }
        let container = try FokusStore.makeContainer(mode: .local, storeURL: url)
        opened = container
        return container
    }

    /// Her okuma/yazma yeni bir bağlamla: uzantı en güncel depo içeriğini görür.
    static func context() throws -> ModelContext { ModelContext(try container()) }

    /// Widget zaman çizelgelerini yeniler (veri değişince çağrılır).
    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

/// Bir andaki sistem görünümü verisi (widget + Live Activity + intent yanıtları için).
struct FokusSystemSnapshot: Sendable {
    var focus: WidgetCalc.FocusSummary
    var tasks: WidgetCalc.TaskList
    var activity: FocusActivityCalc.State?
    var activeSessionId: UUID?
    var activeSubjectLabel: String?
    var goalMinutes: Int?
}

extension FokusSystem {
    static func snapshot(now: Date = .now, calendar: Calendar = .current) throws -> FokusSystemSnapshot {
        let context = try context()
        let sessions = try context.fetch(FetchDescriptor<FocusSession>()).filter(\.isLive)
        let segments = try context.fetch(FetchDescriptor<FocusSegment>()).filter(\.isLive)
        let subjects = try context.fetch(FetchDescriptor<Subject>()).filter(\.isLive)
        let tasks = try context.fetch(FetchDescriptor<StudyTask>()).filter(\.isLive)
        let completions = try context.fetch(FetchDescriptor<TaskCompletion>()).filter(\.isLive)
        let profile = try ProfileRepository(context: context).current()

        let sessionSnapshots = sessions.map(\.snapshot)
        let segmentSnapshots = segments.map(\.snapshot)
        let activeSession = sessions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
        let subjectLabel = activeSession.flatMap { session in
            subjects.first { $0.id == session.subjectId }?.name
        }
        return FokusSystemSnapshot(
            focus: WidgetCalc.focusSummary(
                sessions: sessionSnapshots, segments: segmentSnapshots,
                goalMinutes: profile?.dailyFocusGoalMinutes, now: now, calendar: calendar),
            tasks: WidgetCalc.todayTasks(
                tasks: tasks.map(\.snapshot), completions: completions.map(\.snapshot),
                subjectNames: Dictionary(subjects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }),
                now: now, calendar: calendar),
            activity: FocusActivityCalc.state(sessions: sessionSnapshots, segments: segmentSnapshots, now: now),
            activeSessionId: activeSession?.id,
            activeSubjectLabel: subjectLabel,
            goalMinutes: profile?.dailyFocusGoalMinutes)
    }
}
