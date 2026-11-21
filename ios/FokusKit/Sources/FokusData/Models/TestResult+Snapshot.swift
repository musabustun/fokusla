import FokusDomain
import Foundation

extension TestResult {
    /// Saf hesaplar (`TestsCalc`) için değer tipi.
    public var snapshot: TestResultSnapshot {
        TestResultSnapshot(
            id: id, subjectId: subjectId, topicId: topicId, takenAt: takenAt,
            correct: correct, wrong: wrong, blank: blank, deletedAt: deletedAt)
    }
}
