import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "tasks")

/// Görev ayrıntısı: bilgiler, rutin istatistiği, tamamla/geri al, miktar, düzenle ve sil.
/// Web `TaskDetail`.
struct TaskDetailView: View {
    let task: StudyTask
    let context: TaskViews.Context
    let subjectGroups: [SubjectGroup]
    /// Başlık gösterilsin mi? (Sheet kendi başlığını gösterdiğinde `false`.)
    var showsTitle = true
    let onDeleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var actionError: String?

    private var snapshot: TaskSnapshot { task.snapshot }
    private var model: TaskViews.RowModel { TaskViews.row(snapshot, context: context, detailed: true) }
    private var isRoutine: Bool { task.kind == .routine }
    private var repository: TasksRepository { TasksRepository(context: modelContext) }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            if showsTitle { header }
            facts
            if isRoutine { routineStats }
            completionControls
            if let actionError {
                Text(actionError).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                    .accessibilityIdentifier("task.detail.error")
            }
            actions
        }
        .sheet(isPresented: $isEditing) {
            TaskFormView(mode: .edit(task), subjectGroups: subjectGroups)
        }
        .confirmationDialog(
            "Bu görev silinsin mi?", isPresented: $isConfirmingDelete, titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive, action: delete)
                .accessibilityIdentifier("task.detail.confirmDelete")
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Görev ve tamamlama geçmişi listelerden kaldırılır.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.detail")
    }

    // MARK: - Bölümler

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.md) {
            Image(systemName: isRoutine ? "repeat" : "calendar.badge.clock")
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityHidden(true)
            Text(task.title).fokusTextStyle(.title3).foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var facts: some View {
        let target = TaskFormatting.quantityText(
            target: task.targetQuantity, actual: nil, unit: task.quantityUnit)
        return VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            FactRow(label: "Tür", value: isRoutine ? "Rutin" : "Ödev")
            if let rule = task.recurrence {
                FactRow(label: "Tekrar", value: TaskFormatting.recurrenceText(rule))
            }
            if let dueDate = task.dueDate {
                FactRow(
                    label: "Son tarih", value: TaskFormatting.longDate(dueDate),
                    caption: model.due?.text, captionIsDanger: model.due?.isOverdue ?? false)
            }
            if let subject = model.subjectName { FactRow(label: "Ders", value: subject) }
            if let target { FactRow(label: "Hedef", value: target, isNumeric: true) }
            if let notes = task.notes { FactRow(label: "Not", value: notes) }
        }
    }

    private var routineStats: some View {
        let rate = TasksCalc.completionRate(
            snapshot, completions: context.completions, today: context.today, calendar: context.calendar)
        let streak = TasksCalc.routineStreak(
            snapshot, completions: context.completions, today: context.today, calendar: context.calendar)
        return HStack(spacing: FokusSpacing.xl) {
            ProgressRing(progress: rate.rate ?? 0, lineWidth: 8, tone: rate.rate == 1 ? .success : .accent) {
                VStack(spacing: 2) {
                    Text("\(TaskFormatting.number(rate.completed))/\(TaskFormatting.number(rate.scheduled))")
                        .fokusTextStyle(.numeralSM)
                    Text("gün").fokusTextStyle(.caption).foregroundStyle(.fkSecondaryLabel)
                }
            }
            .frame(width: 84, height: 84)
            .accessibilityLabel("Son 7 gün tamamlama oranı")
            Metric(
                label: "Seri", value: streak > 0 ? TaskFormatting.streakText(streak) : "Henüz seri yok",
                caption: "Son 7 gün", size: .md, isNumeric: false)
            Spacer(minLength: 0)
        }
        .padding(.vertical, FokusSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.detail.stats")
    }

    private var completionControls: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            if model.isDone {
                Button(action: toggle) { Label("Geri al", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("task.detail.toggle")
            } else {
                Button(action: toggle) { Label("Tamamla", systemImage: "checkmark") }
                    .buttonStyle(.fokusPrimary)
                    .disabled(!model.canToggle)
                    .accessibilityIdentifier("task.detail.toggle")
            }
            if model.canToggle {
                QuantityForm(
                    unit: task.quantityUnit,
                    initial: isRoutine
                        ? TasksCalc.findCompletion(context.completions, taskId: task.id, day: context.today)?.quantity
                        : task.completedQuantity,
                    onSave: saveQuantity
                )
                .id("\(task.id)-\(model.isDone)")
            } else {
                Text("Bu rutin bugün planlı değil.").fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            Divider().overlay(.fkSeparator)
            HStack(spacing: FokusSpacing.md) {
                Button { isEditing = true } label: { Label("Düzenle", systemImage: "pencil") }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("task.detail.edit")
                Button { isConfirmingDelete = true } label: { Label("Sil", systemImage: "trash") }
                    .buttonStyle(.fokusDestructive)
                    .accessibilityIdentifier("task.detail.delete")
            }
        }
    }

    // MARK: - Eylemler

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
            actionError = nil
        } catch {
            logger.error("Görev eylemi başarısız: \(error.localizedDescription, privacy: .public)")
            actionError = "İşlem tamamlanamadı. Tekrar dene."
        }
    }

    private func toggle() {
        perform { try repository.toggleCompletion(task, on: context.today) }
    }

    private func saveQuantity(_ quantity: Int?) {
        perform { try repository.recordQuantity(task, on: context.today, quantity: quantity) }
    }

    private func delete() {
        perform {
            try repository.delete(task)
            onDeleted()
        }
    }
}

/// "Etiket — değer" satırı; altında opsiyonel açıklama (gecikmede `danger`).
private struct FactRow: View {
    let label: String
    let value: String
    var caption: String?
    var captionIsDanger = false
    var isNumeric = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.lg) {
                Text(label).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                Spacer(minLength: FokusSpacing.md)
                VStack(alignment: .trailing, spacing: 2) {
                    Group {
                        if isNumeric { Text(value).fokusTextStyle(.numeralSM) } else { Text(value).font(.subheadline) }
                    }
                    .foregroundStyle(.fkLabel)
                    .multilineTextAlignment(.trailing)
                    if let caption {
                        Text(caption).fokusTextStyle(.footnote)
                            .foregroundStyle(captionIsDanger ? FokusColor(.danger) : FokusColor(.secondaryLabel))
                    }
                }
            }
            .padding(.vertical, FokusSpacing.md)
            Divider().overlay(.fkSeparator)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Gerçekleşen miktar" girişi; kaydetmek görevi de tamamlar.
private struct QuantityForm: View {
    let unit: String?
    let initial: Int?
    let onSave: (Int?) -> Void

    @State private var text: String
    @State private var error: String?

    init(unit: String?, initial: Int?, onSave: @escaping (Int?) -> Void) {
        self.unit = unit
        self.initial = initial
        self.onSave = onSave
        _text = State(initialValue: initial.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            Text("Gerçekleşen miktar").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            HStack(spacing: FokusSpacing.md) {
                HStack {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("task.detail.quantity")
                    if let unit, !unit.isEmpty {
                        Text(unit).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                    }
                }
                .padding(.horizontal, FokusSpacing.md)
                .frame(minHeight: fokusMinTapTarget)
                .overlay(RoundedRectangle(cornerRadius: FokusRadius.md).strokeBorder(.fkSeparatorStrong, lineWidth: 1))
                Button("Miktarı kaydet", action: submit)
                    .buttonStyle(.fokusSecondary)
                    .fixedSize()
                    .accessibilityIdentifier("task.detail.quantitySave")
            }
            if let error {
                Text(error).fokusTextStyle(.footnote).foregroundStyle(.fkDanger)
            }
        }
    }

    private func submit() {
        switch TaskDraft.parseQuantity(text) {
        case .empty:
            error = nil
            onSave(nil)
        case .value(let quantity):
            error = nil
            onSave(quantity)
        case .notPositiveInteger, .tooLarge:
            error = "1 ile \(TaskFormatting.number(TaskDraft.quantityMax)) arasında bir tam sayı gir"
        }
    }
}
