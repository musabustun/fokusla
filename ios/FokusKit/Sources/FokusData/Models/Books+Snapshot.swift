import FokusDomain
import Foundation

// `Book` / `BookProgress` → saf hesap girdileri (`BooksCalc`).

extension Book {
    /// `BooksCalc` girdisi.
    public var snapshot: BookSnapshot {
        BookSnapshot(
            id: id, title: title, publisher: publisher, kind: kind, subjectId: subjectId,
            exam: exam, unit: unit, totalUnits: totalUnits, archivedAt: archivedAt,
            createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

extension BookProgress {
    /// `BooksCalc` girdisi.
    public var snapshot: BookProgressSnapshot {
        BookProgressSnapshot(
            id: id, bookId: bookId, reachedUnit: reachedUnit, topicId: topicId,
            recordedAt: recordedAt, note: note, createdAt: createdAt, deletedAt: deletedAt)
    }
}
