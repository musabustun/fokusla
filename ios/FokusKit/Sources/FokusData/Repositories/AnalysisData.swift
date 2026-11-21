import FokusDomain
import Foundation

/// Analiz ekranlarının tek veri kaynağı (web `useAnalysisData`): kullanıcının alanında görünen
/// dersler, konular, test sonuçları, kitaplar ve `TestsCalc` özetleri. Girdiler (`@Query` sonucu)
/// silinmişleri (`deletedAt != nil`) hariç tutar ve aynı `id`'li kopyaları tekilleştirir.
public struct AnalysisData {
    public let field: YksField
    /// Alanında görünen dersler (sınav → sıra → ad).
    public let subjects: [Subject]
    public let subjectsById: [UUID: Subject]
    /// Görünen derslerin konuları, `order`'a ve ada göre sıralı.
    public let topicsBySubject: [UUID: [Topic]]
    public let topicsById: [UUID: Topic]
    /// Yalnızca görünen derslere ait sonuçlar.
    public let results: [TestResult]
    public let booksById: [UUID: Book]
    public let subjectSummaries: [UUID: TestSummary]
    public let topicSummaries: [UUID: TestSummary]

    private static let examOrder: [ExamType: Int] = [.tyt: 0, .ayt: 1, .ydt: 2]

    /// Alanına ait katalog dersleri + tüm kullanıcı dersleri; sıra: sınav (TYT → AYT → YDT), `order`, ad.
    public static func visibleSubjects(_ subjects: [Subject], field: YksField) -> [Subject] {
        subjects
            .filter { $0.catalogKey == nil || $0.fields.contains(field) }
            .sorted { a, b in
                let (ea, eb) = (examOrder[a.exam] ?? 0, examOrder[b.exam] ?? 0)
                if ea != eb { return ea < eb }
                if a.order != b.order { return a.order < b.order }
                return Self.isOrdered(a.name, before: b.name)
            }
    }

    private static func isOrdered(_ a: String, before b: String) -> Bool {
        a.compare(b, locale: AnalysisFormat.locale) == .orderedAscending
    }

    @MainActor
    public static func build(
        subjects rawSubjects: [Subject], topics rawTopics: [Topic], results rawResults: [TestResult],
        books rawBooks: [Book], field: YksField
    ) -> AnalysisData {
        let visible = visibleSubjects(
            EntityStore<Subject>.deduplicated(rawSubjects.filter(\.isLive)), field: field)
        let subjectIds = Set(visible.map(\.id))

        var grouped: [UUID: [Topic]] = [:]
        for topic in EntityStore<Topic>.deduplicated(rawTopics.filter(\.isLive)) {
            guard let subjectId = topic.subjectId, subjectIds.contains(subjectId) else { continue }
            grouped[subjectId, default: []].append(topic)
        }
        let topicsBySubject = grouped.mapValues { topics in
            topics.sorted { a, b in
                a.order != b.order ? a.order < b.order : Self.isOrdered(a.name, before: b.name)
            }
        }
        let topicsById = Dictionary(
            uniqueKeysWithValues: topicsBySubject.values.joined().map { ($0.id, $0) })

        let results = EntityStore<TestResult>.deduplicated(rawResults.filter(\.isLive))
            .filter { $0.subjectId.map(subjectIds.contains) ?? false }
        let snapshots = results.map(\.snapshot)
        let topicedSnapshots = snapshots.filter { $0.topicId.map { topicsById[$0] != nil } ?? false }

        return AnalysisData(
            field: field,
            subjects: visible,
            subjectsById: Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) }),
            topicsBySubject: topicsBySubject,
            topicsById: topicsById,
            results: results,
            booksById: Dictionary(
                EntityStore<Book>.deduplicated(rawBooks.filter(\.isLive)).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }),
            subjectSummaries: TestsCalc.summarizeBySubject(snapshots),
            topicSummaries: TestsCalc.summarizeByTopic(topicedSnapshots))
    }

    /// Bir dersin sonuçları (en yeni üstte).
    public func results(forSubject subjectId: UUID) -> [TestResult] {
        results.filter { $0.subjectId == subjectId }.sorted { $0.takenAt > $1.takenAt }
    }

    /// Bir konunun sonuçları (en yeni üstte).
    public func results(forTopic topicId: UUID) -> [TestResult] {
        results.filter { $0.topicId == topicId }.sorted { $0.takenAt > $1.takenAt }
    }

    /// Dersin, bir (görünen) konuya bağlı olmayan sonuçları.
    public func untopicedResults(forSubject subjectId: UUID) -> [TestResult] {
        results(forSubject: subjectId).filter { $0.topicId.map { topicsById[$0] == nil } ?? true }
    }

    /// Kitap seçicisi: rafa kaldırılmamış kitaplar (+ düzenlenen kaydın kitabı), ada göre sıralı.
    public func bookOptions(including currentBookId: UUID? = nil) -> [Book] {
        booksById.values
            .filter { $0.archivedAt == nil || $0.id == currentBookId }
            .sorted { Self.isOrdered($0.title, before: $1.title) }
    }
}
