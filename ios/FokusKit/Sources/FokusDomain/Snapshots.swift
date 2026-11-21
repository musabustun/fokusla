import Foundation

// Hesap fonksiyonlarının girdisi olan SAF değer tipleri. `Calc/` SwiftData'yı bilmez;
// FokusData'daki `@Model`'ler `.snapshot` ile bu tiplere dönüşür. Böylece hesaplar
// `Sendable`'dır, test edilir ve web vakaları birebir taşınır.
// Modül oturumları kendi hesapları için gereken snapshot'ları buraya EKLER (ör. TestResult).

/// `FocusSession`'ın hesaplar için gereken alanları.
public struct FocusSessionSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var deletedAt: Date?

    public init(id: UUID, startedAt: Date, endedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deletedAt = deletedAt
    }
}

/// `FocusSegment`'in hesaplar için gereken alanları.
public struct FocusSegmentSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var sessionId: UUID?
    public var kind: FocusSegmentKind
    public var startedAt: Date
    public var endedAt: Date?
    public var deletedAt: Date?

    public init(
        id: UUID, sessionId: UUID?, kind: FocusSegmentKind,
        startedAt: Date, endedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deletedAt = deletedAt
    }
}

/// `StudyTask`'ın (web `Task`) hesaplar için gereken alanları. `TasksCalc` girdisi.
public struct TaskSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var kind: TaskKind
    public var order: Int
    /// Ödevin son tarihi (`ISODate`, yerel gün).
    public var dueDate: ISODate?
    public var recurrence: RecurrenceRule?
    /// Ödevin tamamlandığı an (rutinlerde kullanılmaz).
    public var completedAt: Date?
    /// Rutinin başladığı gün (`ISODate`); yoksa `createdAt`'in yerel günü.
    public var startDate: ISODate?
    public var createdAt: Date
    public var deletedAt: Date?
    public var subjectId: UUID?
    public var targetQuantity: Int?
    public var quantityUnit: String?
    /// Ödevin gerçekleşen miktarı (rutinde tamamlamanın `quantity`'si kullanılır).
    public var completedQuantity: Int?

    public init(
        id: UUID, title: String, kind: TaskKind, order: Int = 0, dueDate: ISODate? = nil,
        recurrence: RecurrenceRule? = nil, completedAt: Date? = nil, startDate: ISODate? = nil,
        createdAt: Date, deletedAt: Date? = nil, subjectId: UUID? = nil, targetQuantity: Int? = nil,
        quantityUnit: String? = nil, completedQuantity: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.order = order
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.completedAt = completedAt
        self.startDate = startDate
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.subjectId = subjectId
        self.targetQuantity = targetQuantity
        self.quantityUnit = quantityUnit
        self.completedQuantity = completedQuantity
    }
}

/// `TaskCompletion`'ın hesaplar için gereken alanları (rutinin bir gündeki tamamlanması).
public struct TaskCompletionSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var taskId: UUID?
    /// `ISODate` (yerel gün).
    public var date: ISODate
    public var completedAt: Date
    public var deletedAt: Date?
    /// O gün gerçekleşen miktar.
    public var quantity: Int?

    public init(
        id: UUID, taskId: UUID?, date: ISODate, completedAt: Date, deletedAt: Date? = nil,
        quantity: Int? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.date = date
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.quantity = quantity
    }
}

/// `TestResult`'ın hesaplar için gereken alanları (Analiz modülü).
public struct TestResultSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var subjectId: UUID?
    public var topicId: UUID?
    public var takenAt: Date
    public var correct: Int
    public var wrong: Int
    public var blank: Int
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(), subjectId: UUID?, topicId: UUID? = nil, takenAt: Date,
        correct: Int, wrong: Int, blank: Int, deletedAt: Date? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.topicId = topicId
        self.takenAt = takenAt
        self.correct = correct
        self.wrong = wrong
        self.blank = blank
        self.deletedAt = deletedAt
    }
}
