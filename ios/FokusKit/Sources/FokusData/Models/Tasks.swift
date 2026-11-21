import FokusDomain
import Foundation
import SwiftData

/// Görev (web `Task`). Swift `Task` ile çakışmasın diye `StudyTask`; CloudKit kayıt tipi `CD_StudyTask`.
@Model
public final class StudyTask: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var title: String = ""
    public var kindRaw: String = "assignment"
    public var notes: String?
    public var subjectId: UUID?
    /// `ISODate` (YYYY-MM-DD, yerel gün).
    public var dueDate: String?
    public var recurrence: RecurrenceRule?
    public var completedAt: Date?
    public var order: Int = 0
    /// `ISODate`.
    public var startDate: String?
    public var targetQuantity: Int?
    public var quantityUnit: String?
    public var completedQuantity: Int?

    public init(
        id: UUID = UUID(), title: String, kind: TaskKind, notes: String? = nil,
        subjectId: UUID? = nil, dueDate: ISODate? = nil, recurrence: RecurrenceRule? = nil,
        completedAt: Date? = nil, order: Int = 0, startDate: ISODate? = nil,
        targetQuantity: Int? = nil, quantityUnit: String? = nil, completedQuantity: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.notes = notes
        self.subjectId = subjectId
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.completedAt = completedAt
        self.order = order
        self.startDate = startDate
        self.targetQuantity = targetQuantity
        self.quantityUnit = quantityUnit
        self.completedQuantity = completedQuantity
    }

    public var kind: TaskKind {
        get { TaskKind(rawValue: kindRaw) ?? .assignment }
        set { kindRaw = newValue.rawValue }
    }
}

/// Rutin görevin bir gündeki tamamlanması (web `TaskCompletion`). `(taskId, date)` tekilliği
/// CloudKit'te zorlanamaz; okurken tekilleştir, yazarken "varsa güncelle".
@Model
public final class TaskCompletion: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var taskId: UUID?
    /// `ISODate`.
    public var date: String = ""
    public var completedAt: Date = Date.now
    public var quantity: Int?

    public init(
        id: UUID = UUID(), taskId: UUID?, date: ISODate,
        completedAt: Date = .now, quantity: Int? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.date = date
        self.completedAt = completedAt
        self.quantity = quantity
    }
}
