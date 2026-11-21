import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "tasks")

/// Görev oluşturma/düzenleme sayfası (web `AddTaskSheet` + `TaskForm`). Durum `TaskDraft`'tadır;
/// doğrulama `TaskDraft.validate()`, yazma `TasksRepository`.
struct TaskFormView: View {
    enum Mode {
        case create(today: ISODate)
        case edit(StudyTask)
    }

    let mode: Mode
    let subjectGroups: [SubjectGroup]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fokusPalette) private var palette
    @State private var draft: TaskDraft
    @State private var errors: [TaskDraft.Field: String] = [:]
    @State private var saveError: String?

    init(mode: Mode, subjectGroups: [SubjectGroup]) {
        self.mode = mode
        self.subjectGroups = subjectGroups
        switch mode {
        case .create(let today): _draft = State(initialValue: .empty(.routine, today: today))
        case .edit(let task): _draft = State(initialValue: TaskDraft(task: task))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isRoutine: Bool { draft.kind == .routine }
    private var rowBackground: Color { FokusColor.color(.surface, palette: palette) }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing { kindSection }
                titleSection
                if isRoutine { recurrenceSection } else { dueDateSection }
                subjectSection
                quantitySection
                notesSection
                if let saveError {
                    Section { Text(saveError).foregroundStyle(.fkDanger).fokusTextStyle(.subheadline) }
                        .listRowBackground(rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.fkBackground)
            .navigationTitle(isEditing ? "Görevi düzenle" : "Yeni görev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }.accessibilityIdentifier("task.form.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).fontWeight(.semibold)
                        .accessibilityIdentifier("task.form.save")
                }
            }
        }
        .accessibilityIdentifier("task.form")
    }

    // MARK: - Bölümler

    private var kindSection: some View {
        Section {
            Picker("Tür", selection: $draft.kind) {
                Text("Rutin").tag(TaskKind.routine)
                Text("Ödev").tag(TaskKind.assignment)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("task.form.kind")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var titleSection: some View {
        Section {
            TextField(
                isRoutine ? "Ör. 50 paragraf sorusu" : "Ör. Fizik ödev föyü 3", text: $draft.title
            )
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .accessibilityIdentifier("task.form.title")
            .listRowBackground(rowBackground)
        } header: {
            header("Başlık")
        } footer: {
            errorText(.title)
        }
    }

    private var recurrenceSection: some View {
        Section {
            Picker("Tekrar", selection: $draft.frequency) {
                Text("Her gün").tag(RecurrenceFrequency.daily)
                Text("Belirli günler").tag(RecurrenceFrequency.weekly)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("task.form.frequency")
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            if draft.frequency == .weekly {
                WeekdayPicker(selection: $draft.weekdays, isInvalid: errors[.weekdays] != nil)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: FokusSpacing.sm, leading: 0, bottom: 0, trailing: 0))
            }
        } header: {
            header("Tekrar")
        } footer: {
            errorText(.weekdays)
        }
    }

    private var dueDateSection: some View {
        Section {
            DatePicker(
                "Son tarih", selection: dueDateBinding, displayedComponents: .date
            )
            .environment(\.locale, Locale(identifier: "tr_TR"))
            .accessibilityIdentifier("task.form.dueDate")
            .listRowBackground(rowBackground)
        } header: {
            header("Son tarih")
        } footer: {
            errorText(.dueDate)
        }
    }

    private var subjectSection: some View {
        Section {
            Picker("Ders", selection: $draft.subjectId) {
                Text("Ders yok").tag(UUID?.none)
                ForEach(subjectGroups) { group in
                    Section(group.exam.rawValue) {
                        ForEach(group.subjects) { subject in
                            Text(subject.name).tag(UUID?.some(subject.id))
                        }
                    }
                }
            }
            .accessibilityIdentifier("task.form.subject")
            .listRowBackground(rowBackground)
        } header: {
            header("Ders")
        }
    }

    private var quantitySection: some View {
        Section {
            HStack {
                TextField("Hedef miktar (isteğe bağlı)", text: $draft.targetQuantity)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("task.form.target")
                Divider()
                TextField("Birim (soru)", text: $draft.quantityUnit)
                    .accessibilityIdentifier("task.form.unit")
            }
            .listRowBackground(rowBackground)
        } header: {
            header("Hedef")
        } footer: {
            VStack(alignment: .leading) {
                errorText(.targetQuantity)
                errorText(.quantityUnit)
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextField("İsteğe bağlı", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("task.form.notes")
                .listRowBackground(rowBackground)
        } header: {
            header("Not")
        } footer: {
            errorText(.notes)
        }
    }

    // MARK: - Yardımcılar

    private func header(_ title: String) -> some View {
        Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
    }

    @ViewBuilder private func errorText(_ field: TaskDraft.Field) -> some View {
        if let message = errors[field] {
            Text(message).fokusTextStyle(.footnote).foregroundStyle(.fkDanger)
                .accessibilityIdentifier("task.form.error.\(field.rawValue)")
        }
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { TaskISODate.date(from: draft.dueDate) ?? .now },
            set: { draft.dueDate = TaskISODate.isoDate(from: $0) })
    }

    private func save() {
        switch draft.validate() {
        case .invalid(let found):
            errors = found
        case .valid(let values):
            errors = [:]
            do {
                let repository = TasksRepository(context: modelContext)
                switch mode {
                case .create(let today): try repository.create(values, today: today)
                case .edit(let task): try repository.update(task, with: values)
                }
                dismiss()
            } catch {
                logger.error("Görev kaydedilemedi: \(error.localizedDescription, privacy: .public)")
                saveError = "Görev kaydedilemedi. Tekrar dene."
            }
        }
    }
}
