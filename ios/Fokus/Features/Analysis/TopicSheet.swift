import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Kullanıcı tanımlı konu ekle / yeniden adlandır / sil (web `TopicSheet`). Katalog konuları düzenlenemez.
struct TopicSheet: View {
    let subjectId: UUID
    let editing: Topic?
    let existingCount: Int
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var isSubmitted = false
    @State private var saveError: String?
    @State private var showsDeleteConfirm = false

    init(subjectId: UUID, editing: Topic?, existingCount: Int, onClose: @escaping () -> Void) {
        self.subjectId = subjectId
        self.editing = editing
        self.existingCount = existingCount
        self.onClose = onClose
        _name = State(initialValue: editing?.name ?? "")
    }

    private var validation: EntityNameValidation.Result {
        EntityNameValidation.validate(
            name, label: "Konu adı", maxLength: EntityNameValidation.maxTopicNameLength)
    }

    private var nameError: String? {
        guard isSubmitted, case .invalid(let message) = validation else { return nil }
        return message
    }

    var body: some View {
        NavigationStack {
            if editing?.isCatalogEntry == true {
                EmptyStateView("Konu", message: "Müfredat konuları düzenlenemez.")
                    .background(.fkBackground)
                    .toolbar { cancelItem }
            } else {
                form
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("analysis.topicSheet")
        .confirmationDialog(
            AnalysisSheetText.deleteConfirmTitle, isPresented: $showsDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Konuyu sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(AnalysisSheetText.topicDeleteMessage)
        }
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Vazgeç", action: onClose).accessibilityIdentifier("analysis.cancel")
        }
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("Konu adı") {
                    TextField("Konu adı", text: $name, prompt: Text("Ör. Karışım problemleri"))
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("analysis.field.name")
                }
                FieldErrorText(text: nameError)
            }
.analysisRows()
            if editing != nil {
                Section {
                    Button("Konuyu sil", role: .destructive) { showsDeleteConfirm = true }
                        .accessibilityIdentifier("analysis.delete")
                }
.analysisRows()
            }
        }
        .analysisFormStyle()
        .navigationTitle(editing == nil ? "Konu ekle" : "Konuyu düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelItem }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FokusSpacing.sm) {
                if let saveError { FieldErrorText(text: saveError) }
                Button("Kaydet", action: save)
                    .buttonStyle(.fokusPrimary)
                    .accessibilityIdentifier("analysis.save")
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.md)
            .background(.fkBackground)
        }
    }

    private func save() {
        isSubmitted = true
        guard case .valid(let validName) = validation else { return }
        do {
            let repository = AnalysisRepository(context: modelContext)
            if let editing {
                try repository.updateTopic(editing, name: validName)
            } else {
                try repository.addTopic(subjectId: subjectId, name: validName, existingCount: existingCount)
            }
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }

    private func delete() {
        guard let editing else { return }
        do {
            try AnalysisRepository(context: modelContext).deleteTopic(editing)
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }
}
