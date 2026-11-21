import FokusData
import FokusDomain
import Foundation

/// Ders/konu listeleme yardımcıları — web `features/focus/subjects.ts`.
enum FocusSubjects {
    private static let examOrder: [ExamType] = [.tyt, .ayt, .ydt]

    /// Profilin alanına ait dersler (profil yoksa hepsi), önce sınav sonra `order` sırasıyla.
    static func subjects(_ subjects: [Subject], field: YksField?) -> [Subject] {
        subjects
            .filter { subject in field.map(subject.fields.contains) ?? true }
            .sorted { lhs, rhs in
                let (left, right) = (rank(lhs.exam), rank(rhs.exam))
                if left != right { return left < right }
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.name.compare(rhs.name, locale: Locale(identifier: "tr_TR")) == .orderedAscending
            }
    }

    /// Sınava göre gruplanmış dersler; sınav sırası korunur, boş gruplar atlanır.
    static func groupedByExam(_ subjects: [Subject]) -> [(exam: ExamType, subjects: [Subject])] {
        examOrder.compactMap { exam in
            let group = subjects.filter { $0.exam == exam }
            return group.isEmpty ? nil : (exam, group)
        }
    }

    /// Dersin konuları, `order` sırasıyla.
    static func topics(_ topics: [Topic], subjectId: UUID?) -> [Topic] {
        guard let subjectId else { return [] }
        return topics.filter { $0.subjectId == subjectId }.sorted { $0.order < $1.order }
    }

    private static func rank(_ exam: ExamType) -> Int {
        examOrder.firstIndex(of: exam) ?? examOrder.count
    }
}
