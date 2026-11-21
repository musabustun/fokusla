import FokusData
import SwiftUI

/// Analiz içi gezinme hedefleri (iPhone'da `NavigationStack`, iPad'de ayrıntı bölmesi).
enum AnalysisRoute: Hashable {
    case subject(UUID)
    case topic(subjectId: UUID, topicId: UUID)
}

/// Ekranın açabildiği sayfalar (sheet).
enum AnalysisSheet: Identifiable {
    case test(editing: TestResult?, subjectId: UUID?, topicId: UUID?)
    case subject(editing: Subject?)
    case topic(subjectId: UUID, editing: Topic?)

    var id: String {
        switch self {
        case .test(let editing, _, _): "test-\(editing?.id.uuidString ?? "new")"
        case .subject(let editing): "subject-\(editing?.id.uuidString ?? "new")"
        case .topic(_, let editing): "topic-\(editing?.id.uuidString ?? "new")"
        }
    }
}

/// Derin görünümlerin sheet açmak için çağırdığı eylemler (ortam üzerinden).
struct AnalysisActions: Sendable {
    var addTest: @MainActor @Sendable (_ subjectId: UUID?, _ topicId: UUID?) -> Void
    var editResult: @MainActor @Sendable (TestResult) -> Void
    var addSubject: @MainActor @Sendable () -> Void
    var editSubject: @MainActor @Sendable (Subject) -> Void
    var addTopic: @MainActor @Sendable (Subject) -> Void
    var editTopic: @MainActor @Sendable (Topic) -> Void

    static let noop = AnalysisActions(
        addTest: { _, _ in }, editResult: { _ in }, addSubject: {}, editSubject: { _ in },
        addTopic: { _ in }, editTopic: { _ in })
}

extension EnvironmentValues {
    @Entry var analysisActions: AnalysisActions = .noop
}
