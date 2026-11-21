import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

// Görev repository testleri — web `taskModel.test.ts` içindeki `newTaskInput / taskPatch` ve
// `repository eylemleri` vakalarının karşılığı (aynı senaryolar ve değerler).

private let today = "2026-11-19"
private let tomorrow = "2026-11-20"
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let now = t0
private let later = t0.addingTimeInterval(4.5 * 3600)

private func routineValues(
    title: String = "Paragraf çöz", recurrence: RecurrenceRule? = RecurrenceRule(frequency: .daily),
    targetQuantity: Int? = 40, quantityUnit: String? = "soru"
) -> TaskValues {
    TaskValues(
        kind: .routine, title: title, notes: nil, subjectId: nil, dueDate: nil, recurrence: recurrence,
        targetQuantity: targetQuantity, quantityUnit: quantityUnit)
}

private func assignmentValues(title: String = "Deneme analizi") -> TaskValues {
    TaskValues(
        kind: .assignment, title: title, notes: "Yanlışları not al", subjectId: nil, dueDate: tomorrow,
        recurrence: nil, targetQuantity: nil, quantityUnit: nil)
}

@MainActor
struct TasksRepositoryTests {
    private func make() throws -> (TasksRepository, ModelContext) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        return (TasksRepository(context: context), context)
    }

    private func allCompletions(_ context: ModelContext) throws -> [TaskCompletion] {
        try EntityStore<TaskCompletion>(context: context).all(includeDeleted: true)
    }

    // MARK: - create

    @Test func createOrderIsMaxPlusOneAmongLiveTasks() throws {
        let (repo, context) = try make()
        let first = try repo.create(routineValues(), today: today, now: now)
        let second = try repo.create(assignmentValues(), today: today, now: now)
        #expect(first.order == 0)
        #expect(second.order == 1)

        EntityStore<StudyTask>(context: context).softDelete(second, now: now)
        let third = try repo.create(routineValues(title: "Üçüncü"), today: today, now: now)
        #expect(third.order == 1)
    }

    @Test func createRoutineSetsStartDateAndAssignmentDoesNot() throws {
        let (repo, _) = try make()
        let values = routineValues(recurrence: RecurrenceRule(frequency: .weekly, weekdays: [1, 4]))
        let routine = try repo.create(values, today: today, now: now)
        let assignment = try repo.create(assignmentValues(), today: today, now: now)

        #expect(routine.kind == .routine)
        #expect(routine.title == "Paragraf çöz")
        #expect(routine.startDate == today)
        #expect(routine.completedAt == nil && routine.completedQuantity == nil)
        #expect(routine.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [1, 4]))
        #expect(routine.targetQuantity == 40 && routine.quantityUnit == "soru")
        #expect(routine.dueDate == nil)
        #expect(routine.createdAt == now && routine.updatedAt == now)

        #expect(assignment.kind == .assignment)
        #expect(assignment.startDate == nil)
        #expect(assignment.dueDate == tomorrow)
        #expect(assignment.recurrence == nil)
        #expect(assignment.notes == "Yanlışları not al")

        #expect(try repo.tasks().map(\.id) == [routine.id, assignment.id])
    }

    @Test func createStoresSubjectId() throws {
        let (repo, _) = try make()
        let subject = UUID()
        var values = routineValues()
        values.subjectId = subject
        let task = try repo.create(values, today: today, now: now)
        #expect(task.subjectId == subject)
    }

    // MARK: - update

    @Test func updateChangesFieldsButNotKindStartDateOrOrder() throws {
        let (repo, _) = try make()
        let task = try repo.create(routineValues(), today: "2026-11-01", now: now)
        let order = task.order

        let values = TaskValues(
            kind: .assignment, title: "Yeni başlık", notes: "not", subjectId: nil, dueDate: nil,
            recurrence: RecurrenceRule(frequency: .weekly, weekdays: [2]), targetQuantity: nil,
            quantityUnit: nil)
        try repo.update(task, with: values, now: later)

        #expect(task.kind == .routine)
        #expect(task.startDate == "2026-11-01")
        #expect(task.order == order)
        #expect(task.title == "Yeni başlık")
        #expect(task.notes == "not")
        #expect(task.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [2]))
        #expect(task.targetQuantity == nil && task.quantityUnit == nil)
        #expect(task.createdAt == now && task.updatedAt == later)
    }

    // MARK: - delete

    @Test func deleteSoftDeletesTaskAndItsCompletionsOnly() throws {
        let (repo, context) = try make()
        let task = try repo.create(routineValues(), today: today, now: now)
        try repo.toggleCompletion(task, on: today, now: now)
        try repo.toggleCompletion(task, on: tomorrow, now: now)
        let other = try repo.create(routineValues(title: "Diğer"), today: today, now: now)
        try repo.toggleCompletion(other, on: today, now: now)

        try repo.delete(task, now: later)

        #expect(try repo.tasks().map(\.id) == [other.id])
        let taskStore = EntityStore<StudyTask>(context: context)
        #expect(try taskStore.find(id: task.id) == nil)
        #expect(try taskStore.find(id: task.id, includeDeleted: true)?.deletedAt == later)
        #expect(try repo.completions(taskId: task.id).isEmpty)

        let all = try allCompletions(context)
        let mine = all.filter { $0.taskId == task.id }
        #expect(mine.count == 2)
        #expect(mine.allSatisfy { $0.deletedAt == later })
        #expect(try repo.completions(taskId: other.id).count == 1)
        #expect(all.filter { $0.taskId == other.id }.allSatisfy { $0.deletedAt == nil })
    }

    @Test func deleteAssignment() throws {
        let (repo, _) = try make()
        let task = try repo.create(assignmentValues(), today: today, now: now)
        try repo.delete(task, now: later)
        #expect(try repo.tasks().isEmpty)
    }

    // MARK: - toggleCompletion — rutin

    @Test func routineToggleOnOffOnCreatesNewRecord() throws {
        let (repo, _) = try make()
        let task = try repo.create(routineValues(), today: today, now: now)

        #expect(try repo.toggleCompletion(task, on: today, now: now) == true)
        let first = try #require(try repo.completions(taskId: task.id).first)
        #expect(first.taskId == task.id && first.date == today)
        #expect(first.completedAt == now && first.quantity == nil)

        #expect(try repo.toggleCompletion(task, on: today, now: later) == false)
        #expect(try repo.completions(taskId: task.id).isEmpty)

        #expect(try repo.toggleCompletion(task, on: today, now: later, quantity: 12) == true)
        let active = try repo.completions(taskId: task.id)
        #expect(active.count == 1)
        let second = try #require(active.first)
        #expect(second.id != first.id)
        #expect(second.completedAt == later && second.quantity == 12)
    }

    @Test func routineUndoRemovesAllDuplicatesOfThatDayOnly() throws {
        let (repo, context) = try make()
        let task = try repo.create(routineValues(), today: today, now: now)
        let store = EntityStore<TaskCompletion>(context: context)
        store.insert(TaskCompletion(taskId: task.id, date: today, completedAt: now, quantity: nil), now: now)
        store.insert(
            TaskCompletion(taskId: task.id, date: today, completedAt: now, quantity: 5),
            now: now.addingTimeInterval(1))
        try store.save()
        try repo.toggleCompletion(task, on: tomorrow, now: now)

        #expect(try repo.toggleCompletion(task, on: today, now: later) == false)
        let remaining = try repo.completions(taskId: task.id)
        #expect(remaining.count == 1)
        #expect(remaining.first?.date == tomorrow)
        #expect(try allCompletions(context).filter { $0.date == today }.allSatisfy { $0.deletedAt == later })
    }

    // MARK: - toggleCompletion — ödev

    @Test func assignmentCompleteUndoComplete() throws {
        let (repo, context) = try make()
        let task = try repo.create(assignmentValues(), today: today, now: now)

        #expect(try repo.toggleCompletion(task, on: today, now: now, quantity: 30) == true)
        #expect(task.completedAt == now)
        #expect(task.completedQuantity == 30)

        #expect(try repo.toggleCompletion(task, on: today, now: later) == false)
        #expect(task.completedAt == nil)
        #expect(task.completedQuantity == nil)

        #expect(try repo.toggleCompletion(task, on: today, now: later) == true)
        #expect(task.completedAt == later)
        #expect(task.completedQuantity == nil)
        #expect(task.updatedAt == later)
        #expect(try allCompletions(context).isEmpty)
    }

    // MARK: - recordQuantity

    @Test func recordQuantityRoutineCreatesThenUpdatesOnlyQuantity() throws {
        let (repo, _) = try make()
        let task = try repo.create(routineValues(), today: today, now: now)

        try repo.recordQuantity(task, on: today, now: now, quantity: 25)
        let created = try #require(try repo.completions(taskId: task.id).first)
        #expect(created.date == today && created.completedAt == now && created.quantity == 25)

        try repo.recordQuantity(task, on: today, now: later, quantity: 40)
        let after = try repo.completions(taskId: task.id)
        #expect(after.count == 1)
        #expect(after.first?.id == created.id)
        #expect(after.first?.completedAt == now)
        #expect(after.first?.quantity == 40)
        #expect(after.first?.updatedAt == later)
    }

    @Test func recordQuantityAssignmentSetsCompletedAtOnlyWhenNotCompleted() throws {
        let (repo, _) = try make()
        let task = try repo.create(assignmentValues(), today: today, now: now)

        try repo.recordQuantity(task, on: today, now: now, quantity: 10)
        #expect(task.completedAt == now && task.completedQuantity == 10)

        try repo.recordQuantity(task, on: today, now: later, quantity: nil)
        #expect(task.completedAt == now)
        #expect(task.completedQuantity == nil)
    }

    @Test func recordQuantityOnDeletedTaskThrows() throws {
        let (repo, _) = try make()
        let task = try repo.create(assignmentValues(), today: today, now: now)
        try repo.delete(task, now: later)
        #expect(throws: TasksRepository.RepositoryError.taskDeleted) {
            try repo.recordQuantity(task, on: today, now: now, quantity: 1)
        }
    }

    @Test func toggleCompletionOnDeletedTaskThrows() throws {
        let (repo, context) = try make()
        let task = try repo.create(routineValues(), today: today, now: now)
        try repo.delete(task, now: later)
        #expect(throws: TasksRepository.RepositoryError.taskDeleted) {
            try repo.toggleCompletion(task, on: today, now: now)
        }
        #expect(try allCompletions(context).isEmpty)
    }

    // MARK: - completions(taskId:)

    @Test func completionsFilterByTaskAndExcludeDeleted() throws {
        let (repo, _) = try make()
        let a = try repo.create(routineValues(title: "A"), today: today, now: now)
        let b = try repo.create(routineValues(title: "B"), today: today, now: now)
        try repo.toggleCompletion(a, on: today, now: now)
        try repo.toggleCompletion(b, on: today, now: now)
        try repo.toggleCompletion(b, on: tomorrow, now: now)
        try repo.toggleCompletion(b, on: tomorrow, now: later)  // geri al

        #expect(try repo.completions().count == 2)
        #expect(try repo.completions(taskId: a.id).count == 1)
        #expect(try repo.completions(taskId: b.id).map(\.date) == [today])
        #expect(try repo.completions(taskId: UUID()).isEmpty)
    }
}

// MARK: - Snapshot eşlemeleri

@MainActor
struct TasksSnapshotTests {
    @Test func studyTaskSnapshotMapsAllFields() {
        let id = UUID()
        let subject = UUID()
        let created = t0
        let deleted = t0.addingTimeInterval(60)
        let completed = t0.addingTimeInterval(30)
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [1, 3])
        let task = StudyTask(
            id: id, title: "Paragraf", kind: .routine, notes: "n", subjectId: subject, dueDate: tomorrow,
            recurrence: rule, completedAt: completed, order: 4, startDate: today, targetQuantity: 40,
            quantityUnit: "soru", completedQuantity: 12)
        task.createdAt = created
        task.deletedAt = deleted

        #expect(task.snapshot == TaskSnapshot(
            id: id, title: "Paragraf", kind: .routine, order: 4, dueDate: tomorrow, recurrence: rule,
            completedAt: completed, startDate: today, createdAt: created, deletedAt: deleted,
            subjectId: subject, targetQuantity: 40, quantityUnit: "soru", completedQuantity: 12))
    }

    @Test func taskCompletionSnapshotMapsAllFields() {
        let id = UUID()
        let taskId = UUID()
        let deleted = t0.addingTimeInterval(60)
        let completion = TaskCompletion(id: id, taskId: taskId, date: today, completedAt: t0, quantity: 9)
        completion.deletedAt = deleted

        #expect(completion.snapshot == TaskCompletionSnapshot(
            id: id, taskId: taskId, date: today, completedAt: t0, deletedAt: deleted, quantity: 9))
        #expect(TaskCompletion(taskId: nil, date: today, completedAt: t0).snapshot.taskId == nil)
    }
}

// MARK: - TaskDraft(task:) — web `draftFromTask`

@MainActor
struct TaskDraftFromTaskTests {
    @Test func routineToDraftSortsWeekdaysAndMapsNilToEmpty() {
        let subject = UUID()
        let task = StudyTask(
            title: "Paragraf", kind: .routine, notes: "not", subjectId: subject,
            recurrence: RecurrenceRule(frequency: .weekly, weekdays: [5, 1, 3]), startDate: today,
            targetQuantity: 50, quantityUnit: "soru")

        #expect(TaskDraft(task: task) == TaskDraft(
            kind: .routine, title: "Paragraf", notes: "not", subjectId: subject, frequency: .weekly,
            weekdays: [1, 3, 5], dueDate: "", targetQuantity: "50", quantityUnit: "soru"))
        #expect(task.recurrence?.weekdays == [5, 1, 3])
    }

    @Test func assignmentWithoutOptionalFields() {
        let task = StudyTask(title: "Paragraf", kind: .assignment, dueDate: tomorrow)
        let draft = TaskDraft(task: task)
        #expect(draft.kind == .assignment)
        #expect(draft.frequency == .daily)
        #expect(draft.weekdays == [])
        #expect(draft.dueDate == tomorrow)
        #expect(draft.notes == "")
        #expect(draft.subjectId == nil)
        #expect(draft.targetQuantity == "")
        #expect(draft.quantityUnit == "")
    }

    @Test func draftRoundTripsThroughValidate() {
        let task = StudyTask(
            title: "Paragraf", kind: .routine,
            recurrence: RecurrenceRule(frequency: .weekly, weekdays: [7, 2]), startDate: today,
            targetQuantity: 1000, quantityUnit: "soru")
        let draft = TaskDraft(task: task)
        #expect(draft.targetQuantity == "1000")
        guard case let .valid(values) = draft.validate() else {
            Issue.record("Geçerli taslak bekleniyordu")
            return
        }
        #expect(values.recurrence == RecurrenceRule(frequency: .weekly, weekdays: [2, 7]))
        #expect(values.targetQuantity == 1000)
    }
}
