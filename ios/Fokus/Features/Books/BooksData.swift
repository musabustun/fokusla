import FokusData
import FokusDomain
import Foundation

/// Ders seçicisi için sınava göre gruplanmış dersler.
struct BookSubjectGroup: Identifiable {
    let exam: ExamType
    let subjects: [Subject]
    var id: ExamType { exam }
}

/// `@Query` sonuçlarından türetilen kitap görünümü verisi (web `useBooksData`).
/// Tüm hesaplar `BooksCalc`'tan gelir; burada yalnızca CloudKit kopyalarının tekilleştirilmesi,
/// ders adı eşlemesi ve ders gruplama vardır.
struct BooksData {
    let summaries: [BooksCalc.BookSummary]
    let subjectNames: [UUID: String]
    let subjectGroups: [BookSubjectGroup]

    init(books: [Book], progress: [BookProgress], subjects: [Subject], now: Date) {
        summaries = BooksCalc.summarizeBooks(
            Self.deduplicated(books).map(\.snapshot),
            progress: Self.deduplicated(progress).map(\.snapshot), now: now)
        let sorted = Self.sortedSubjects(Self.deduplicated(subjects))
        subjectNames = Dictionary(sorted.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        subjectGroups = [ExamType.tyt, .ayt, .ydt].compactMap { exam in
            let inExam = sorted.filter { $0.exam == exam }
            return inExam.isEmpty ? nil : BookSubjectGroup(exam: exam, subjects: inExam)
        }
    }

    func summary(for bookId: UUID) -> BooksCalc.BookSummary? {
        summaries.first { $0.book.id == bookId }
    }

    /// Özetin dersi; ders seçilmediyse ya da silinmişse `nil`.
    func subjectName(of summary: BooksCalc.BookSummary) -> String? {
        summary.book.subjectId.flatMap { subjectNames[$0] }
    }

    /// Bir kitabın silinmemiş ilerleme kayıtları, en yeni önce.
    static func history(of bookId: UUID, in progress: [BookProgress]) -> [BookProgress] {
        deduplicated(progress)
            .filter { $0.bookId == bookId }
            .sorted { lhs, rhs in
                if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
                return lhs.createdAt > rhs.createdAt
            }
    }

    /// Aynı `id`'li kopyalarda en eski `createdAt` kazanır (CloudKit); sıra korunur.
    static func deduplicated<T: SyncedEntity>(_ entities: [T]) -> [T] {
        var winners: [UUID: T] = [:]
        for entity in entities {
            if let current = winners[entity.id], current.createdAt <= entity.createdAt { continue }
            winners[entity.id] = entity
        }
        return entities.filter { winners[$0.id] === $0 }
    }

    private static func sortedSubjects(_ subjects: [Subject]) -> [Subject] {
        let examOrder: [ExamType] = [.tyt, .ayt, .ydt]
        func rank(_ exam: ExamType) -> Int { examOrder.firstIndex(of: exam) ?? examOrder.count }
        return subjects.sorted { lhs, rhs in
            if rank(lhs.exam) != rank(rhs.exam) { return rank(lhs.exam) < rank(rhs.exam) }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.name.compare(rhs.name, locale: Locale(identifier: "tr_TR")) == .orderedAscending
        }
    }
}
