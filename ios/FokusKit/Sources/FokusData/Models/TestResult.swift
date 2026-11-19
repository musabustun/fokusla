import Foundation
import SwiftData

/// Test sonucu (web `TestResult`). Net (D − Y/4) SAKLANMAZ; `domain/calc` hesaplar.
@Model
public final class TestResult: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var subjectId: UUID?
    public var topicId: UUID?
    public var bookId: UUID?
    public var label: String?
    public var sourceName: String?
    public var takenAt: Date = Date.now
    public var correct: Int = 0
    public var wrong: Int = 0
    public var blank: Int = 0
    public var durationSeconds: Int?
    public var note: String?

    public init(
        id: UUID = UUID(), subjectId: UUID?, topicId: UUID? = nil, bookId: UUID? = nil,
        label: String? = nil, sourceName: String? = nil, takenAt: Date = .now,
        correct: Int, wrong: Int, blank: Int, durationSeconds: Int? = nil, note: String? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.topicId = topicId
        self.bookId = bookId
        self.label = label
        self.sourceName = sourceName
        self.takenAt = takenAt
        self.correct = correct
        self.wrong = wrong
        self.blank = blank
        self.durationSeconds = durationSeconds
        self.note = note
    }
}
