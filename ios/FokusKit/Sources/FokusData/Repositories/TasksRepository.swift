import FokusDomain
import Foundation
import SwiftData

/// Görev ve tamamlama okuma/yazma. Sahibi: tasks modülü. Web `features/tasks/taskModel.ts`
/// repository eylemlerinin (`createTask`, `updateTask`, `deleteTask`, `toggleCompletion`,
/// `recordQuantity`) karşılığıdır.
///
/// Tüm saat bilgisi `now` parametresiyle gelir; gün (`day`/`today`) YEREL `ISODate`'tir.
/// Silme yumuşaktır (`deletedAt`); okumalar silinenleri hariç tutar.
@MainActor
public struct TasksRepository {
    public enum RepositoryError: Error, Equatable, Sendable {
        /// Silinmiş bir görev üzerinde tamamla/miktar işlemi.
        case taskDeleted
    }

    private let tasksStore: EntityStore<StudyTask>
    private let completionsStore: EntityStore<TaskCompletion>

    public init(context: ModelContext) {
        tasksStore = EntityStore(context: context)
        completionsStore = EntityStore(context: context)
    }

    // MARK: - Okuma

    /// Silinmemiş görevler (`id` ile tekilleştirilmiş).
    public func tasks() throws -> [StudyTask] { try tasksStore.all() }

    /// Silinmemiş tamamlamalar; `taskId` verilirse yalnızca o görevinkiler.
    public func completions(taskId: UUID? = nil) throws -> [TaskCompletion] {
        let all = try completionsStore.all()
        guard let taskId else { return all }
        return all.filter { $0.taskId == taskId }
    }

    // MARK: - Yazma

    /// Yeni görev oluşturur; `order` = silinmemiş görevlerin en büyük `order`'ı + 1 (yoksa 0).
    /// Rutinde `startDate = today` (ödevde `nil`).
    @discardableResult
    public func create(_ values: TaskValues, today: ISODate, now: Date = .now) throws -> StudyTask {
        let order = try tasksStore.all().reduce(0) { Swift.max($0, $1.order + 1) }
        let task = tasksStore.insert(
            StudyTask(
                title: values.title, kind: values.kind, notes: values.notes,
                subjectId: values.subjectId, dueDate: values.dueDate, recurrence: values.recurrence,
                completedAt: nil, order: order,
                startDate: values.kind == .routine ? today : nil,
                targetQuantity: values.targetQuantity, quantityUnit: values.quantityUnit,
                completedQuantity: nil),
            now: now)
        try tasksStore.save()
        return task
    }

    /// Alanları günceller; `kind`, `startDate` ve `order` değişmez.
    public func update(_ task: StudyTask, with values: TaskValues, now: Date = .now) throws {
        task.title = values.title
        task.notes = values.notes
        task.subjectId = values.subjectId
        task.dueDate = values.dueDate
        task.recurrence = values.recurrence
        task.targetQuantity = values.targetQuantity
        task.quantityUnit = values.quantityUnit
        tasksStore.touch(task, now: now)
        try tasksStore.save()
    }

    /// Görevi ve tüm tamamlamalarını yumuşak siler.
    public func delete(_ task: StudyTask, now: Date = .now) throws {
        for completion in try completions(taskId: task.id) {
            completionsStore.softDelete(completion, now: now)
        }
        tasksStore.softDelete(task, now: now)
        try tasksStore.save()
    }

    /// Tek dokunuşla tamamla/geri al (`day` için). Dönüş: işlem sonrası tamamlanmış mı.
    /// - rutin: o güne ait silinmemiş tamamlama varsa HEPSİ silinir (geri al); yoksa yenisi oluşturulur.
    /// - ödev: `completedAt` doluysa temizlenir (`completedQuantity` de); değilse `now` ve `quantity` yazılır.
    @discardableResult
    public func toggleCompletion(
        _ task: StudyTask, on day: ISODate, now: Date = .now, quantity: Int? = nil
    ) throws -> Bool {
        guard task.isLive else { throw RepositoryError.taskDeleted }
        let isCompleted: Bool
        if task.kind == .routine {
            let existing = try completions(of: task, on: day)
            if existing.isEmpty {
                completionsStore.insert(
                    TaskCompletion(taskId: task.id, date: day, completedAt: now, quantity: quantity),
                    now: now)
                isCompleted = true
            } else {
                existing.forEach { completionsStore.softDelete($0, now: now) }
                isCompleted = false
            }
        } else if task.completedAt != nil {
            task.completedAt = nil
            task.completedQuantity = nil
            tasksStore.touch(task, now: now)
            isCompleted = false
        } else {
            task.completedAt = now
            task.completedQuantity = quantity
            tasksStore.touch(task, now: now)
            isCompleted = true
        }
        try tasksStore.save()
        return isCompleted
    }

    /// Gerçekleşen miktarı kaydeder ve görevi tamamlanmış yapar (zaten tamamlanmışsa yalnızca miktarı
    /// günceller). Rutin: o günün tamamlaması (yoksa oluşturulur); ödev: `completedQuantity`
    /// (+ `completedAt` yoksa `now`).
    public func recordQuantity(
        _ task: StudyTask, on day: ISODate, now: Date = .now, quantity: Int?
    ) throws {
        guard task.isLive else { throw RepositoryError.taskDeleted }
        if task.kind == .routine {
            if let first = try completions(of: task, on: day).first {
                first.quantity = quantity
                completionsStore.touch(first, now: now)
            } else {
                completionsStore.insert(
                    TaskCompletion(taskId: task.id, date: day, completedAt: now, quantity: quantity),
                    now: now)
            }
        } else {
            task.completedAt = task.completedAt ?? now
            task.completedQuantity = quantity
            tasksStore.touch(task, now: now)
        }
        try tasksStore.save()
    }

    // MARK: - Yardımcılar

    /// Görevin `day` günündeki silinmemiş tamamlamaları, en eskisi önce.
    private func completions(of task: StudyTask, on day: ISODate) throws -> [TaskCompletion] {
        try completions(taskId: task.id)
            .filter { $0.date == day }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
