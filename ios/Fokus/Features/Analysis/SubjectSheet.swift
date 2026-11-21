import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Kullanıcı tanımlı ders ekle / yeniden adlandır / sil (web `SubjectSheet`). Katalog dersleri düzenlenemez.
struct SubjectSheet: View {
    let field: YksField
    let editing: Subject?
    let existingCount: Int
    let onSaved: (Subject) -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var exam: ExamType
    @State private var isSubmitted = false
    @State private var saveError: String?
    @State private var showsDeleteConfirm = false

    init(
        field: YksField, editing: Subject?, existingCount: Int, onSaved: @escaping (Subject) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.field = field
        self.editing = editing
        self.existingCount = existingCount
        self.onSaved = onSaved
        self.onClose = onClose
        _name = State(initialValue: editing?.name ?? "")
        _exam = State(initialValue: editing?.exam ?? .tyt)
    }

    private var validation: EntityNameValidation.Result {
        EntityNameValidation.validate(
            name, label: "Ders adı", maxLength: EntityNameValidation.maxSubjectNameLength)
    }

    private var nameError: String? {
        guard isSubmitted, case .invalid(let message) = validation else { return nil }
        return message
    }

    var body: some View {
        NavigationStack {
            if editing?.isCatalogEntry == true {
                EmptyStateView("Ders", message: "Müfredat dersleri düzenlenemez.")
                    .background(.fkBackground)
                    .toolbar { cancelItem }
            } else {
                form
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("analysis.subjectSheet")
        .confirmationDialog(
            AnalysisSheetText.deleteConfirmTitle, isPresented: $showsDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Dersi sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(AnalysisSheetText.subjectDeleteMessage)
        }
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Vazgeç", action: onClose).accessibilityIdentifier("analysis.cancel")
        }
    }

    private var saveItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Kaydet", action: save)
                .fontWeight(.semibold)
                .accessibilityIdentifier("analysis.save")
        }
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("Ders adı") {
                    TextField("Ders adı", text: $name, prompt: Text("Ör. Problemler"))
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("analysis.field.name")
                }
                FieldErrorText(text: nameError)
                FieldErrorText(text: saveError)
                Picker("Sınav", selection: $exam) {
                    ForEach(ExamType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("analysis.field.exam")
            }
.analysisRows()
            if editing != nil {
                Section {
                    Button("Dersi sil", role: .destructive) { showsDeleteConfirm = true }
                        .accessibilityIdentifier("analysis.delete")
                }
.analysisRows()
            }
        }
        .analysisFormStyle()
        .navigationTitle(editing == nil ? "Ders ekle" : "Dersi düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            cancelItem
            saveItem
        }
    }

    private func save() {
        isSubmitted = true
        guard case .valid(let validName) = validation else { return }
        do {
            let repository = AnalysisRepository(context: modelContext)
            if let editing {
                try repository.updateSubject(editing, name: validName, exam: exam)
                onSaved(editing)
            } else {
                onSaved(
                    try repository.addSubject(
                        name: validName, exam: exam, field: field, existingCount: existingCount))
            }
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }

    private func delete() {
        guard let editing else { return }
        do {
            try AnalysisRepository(context: modelContext).deleteSubject(editing)
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }
}
