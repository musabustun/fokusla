import FokusDomain
import Foundation

extension StudyTask {
    /// `TasksCalc` girdisi olan saf değer.
    public var snapshot: TaskSnapshot {
        TaskSnapshot(
            id: id, title: title, kind: kind, order: order, dueDate: dueDate,
            recurrence: recurrence, completedAt: completedAt, startDate: startDate,
            createdAt: createdAt, deletedAt: deletedAt, subjectId: subjectId,
            targetQuantity: targetQuantity, quantityUnit: quantityUnit,
            completedQuantity: completedQuantity)
    }
}

extension TaskCompletion {
    /// `TasksCalc` girdisi olan saf değer.
    public var snapshot: TaskCompletionSnapshot {
        TaskCompletionSnapshot(
            id: id, taskId: taskId, date: date, completedAt: completedAt, deletedAt: deletedAt,
            quantity: quantity)
    }
}

extension TaskDraft {
    /// Var olan görevden düzenleme taslağı (günler sıralı, `nil` → "").
    public init(task: StudyTask) {
        self.init(
            kind: task.kind,
            title: task.title,
            notes: task.notes ?? "",
            subjectId: task.subjectId,
            frequency: task.recurrence?.frequencyValue ?? .daily,
            weekdays: TaskDraft.normalizeWeekdays(task.recurrence?.weekdays ?? []),
            dueDate: task.dueDate ?? "",
            targetQuantity: task.targetQuantity.map(String.init) ?? "",
            quantityUnit: task.quantityUnit ?? "")
    }
}
