import AppIntents
import FokusData
import FokusDomain
import Foundation
import SwiftData

/// Siri, Kestirmeler, Live Activity düğmeleri ve widget düğmeleri için App Intents (`ios/Shared`: hem
/// uygulama hem widget hedefine derlenir; `LiveActivityIntent` uygulama sürecinde çalışır).
/// Metin üretimi `FokusDomain.SystemDialogs`ta (test edilir); yazma `FocusActions`ta.

struct FokusIntentError: Error, CustomLocalizedStringResourceConvertible {
    let localizedStringResource: LocalizedStringResource

    static let storeUnavailable = FokusIntentError(
        localizedStringResource: "Fokus verilerine ulaşılamadı. Uygulamayı bir kez açıp tekrar dene.")
}

// MARK: - Ders varlığı

struct SubjectEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Ders")
    static let defaultQuery = SubjectQuery()

    let id: UUID
    let name: String
    let exam: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(exam)")
    }
}

struct SubjectQuery: EntityStringQuery {
    private static let locale = Locale(identifier: "tr_TR")

    @MainActor
    private func allSubjects() throws -> [SubjectEntity] {
        let subjects = try FokusSystem.context().fetch(FetchDescriptor<Subject>()).filter(\.isLive)
        return subjects
            .sorted { ($0.exam.rawValue, $0.order, $0.name) < ($1.exam.rawValue, $1.order, $1.name) }
            .map { SubjectEntity(id: $0.id, name: $0.name, exam: $0.exam.rawValue) }
    }

    @MainActor func entities(for identifiers: [UUID]) async throws -> [SubjectEntity] {
        try allSubjects().filter { identifiers.contains($0.id) }
    }

    @MainActor func entities(matching string: String) async throws -> [SubjectEntity] {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let query = string.folding(options: options, locale: Self.locale)
        return try allSubjects().filter {
            $0.name.folding(options: options, locale: Self.locale).contains(query)
        }
    }

    @MainActor func suggestedEntities() async throws -> [SubjectEntity] { try allSubjects() }
}

// MARK: - Odak

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Odak başlat"
    static let description = IntentDescription("Bir odak oturumu başlatır. Ders seçmek isteğe bağlıdır.")
    /// Canlı etkinlik yalnızca ön plandaki uygulamadan başlatılabilir; tam ekran odak da açılır.
    static let openAppWhenRun = true

    @Parameter(title: "Ders") var subject: SubjectEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome: FocusActions.Outcome
        do { outcome = try FocusActions.start(subjectId: subject?.id) } catch { throw FokusIntentError.storeUnavailable }
        await FocusLiveActivitySync.sync(canStart: true)
        let text =
            outcome == .alreadyRunning
            ? SystemDialogs.focusAlreadyRunning : SystemDialogs.focusStarted(subjectName: subject?.name)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct FinishFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Odağı bitir"
    static let description = IntentDescription("Açık odak oturumunu bitirir.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome: FocusActions.Outcome
        do { outcome = try FocusActions.finish() } catch { throw FokusIntentError.storeUnavailable }
        await FocusLiveActivitySync.sync(canStart: false)
        let text: String
        if case let .finished(focusMs) = outcome {
            text = SystemDialogs.focusFinished(focusMs: focusMs)
        } else {
            text = SystemDialogs.noActiveFocus
        }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

/// Canlı etkinlikteki Mola ver / Devam et düğmesi (Kestirmeler'de gösterilmez).
struct TogglePauseFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mola ver / devam et"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        do { _ = try FocusActions.togglePause() } catch { throw FokusIntentError.storeUnavailable }
        await FocusLiveActivitySync.sync(canStart: false)
        return .result()
    }
}

// MARK: - Bugün ne kadar çalıştım?

struct TodayFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Bugün ne kadar çalıştım?"
    static let description = IntentDescription("Bugünkü toplam odak süreni ve günlük hedefini söyler.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot: FokusSystemSnapshot
        do { snapshot = try FokusSystem.snapshot() } catch { throw FokusIntentError.storeUnavailable }
        let text = SystemDialogs.todaySummary(focusMs: snapshot.focus.focusMs, goalMinutes: snapshot.goalMinutes)
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - Görevler

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Görev ekle"
    static let description = IntentDescription("Bugün teslim edilecek yeni bir görev ekler.")

    @Parameter(title: "Görev", requestValueDialog: "Hangi görevi ekleyeyim?") var taskTitle: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let title = SystemDialogs.normalizedTaskTitle(taskTitle) else {
            return .result(dialog: "Görev adı boş olamaz.")
        }
        do { try FocusActions.addTask(title: title) } catch { throw FokusIntentError.storeUnavailable }
        return .result(dialog: IntentDialog(stringLiteral: SystemDialogs.taskAdded(title: title)))
    }
}

/// Widget'taki işaret düğmesi (Kestirmeler'de gösterilmez). Widget sürecinde çalışır.
struct ToggleTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Görevi tamamla"
    static let isDiscoverable = false

    @Parameter(title: "Görev") var taskId: String

    init() {}
    init(taskId: UUID) { self.taskId = taskId.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskId) else { return .result() }
        do { try FocusActions.toggleTask(id: id) } catch { throw FokusIntentError.storeUnavailable }
        return .result()
    }
}
