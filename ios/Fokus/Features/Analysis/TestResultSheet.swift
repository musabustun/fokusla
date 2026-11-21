import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Test sonucu ekle/düzenle/sil (web `TestResultSheet`).
struct TestResultSheet: View {
    let data: AnalysisData
    let editing: TestResult?
    let defaultSubjectId: UUID?
    let defaultTopicId: UUID?
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @State private var values: TestResultForm.Values
    @State private var isSubmitted = false
    @State private var saveError: String?
    @State private var showsDeleteConfirm = false

    private let today: Date

    init(
        data: AnalysisData, editing: TestResult?, defaultSubjectId: UUID?, defaultTopicId: UUID?,
        onClose: @escaping () -> Void
    ) {
        self.data = data
        self.editing = editing
        self.defaultSubjectId = defaultSubjectId
        self.defaultTopicId = defaultTopicId
        self.onClose = onClose
        let now = Date.now
        today = now
        _values = State(
            initialValue: editing.map {
                TestResultForm.values(
                    subjectId: $0.subjectId, topicId: $0.topicId, bookId: $0.bookId,
                    sourceName: $0.sourceName, label: $0.label, correct: $0.correct, wrong: $0.wrong,
                    blank: $0.blank, takenAt: $0.takenAt)
            }
                ?? TestResultForm.emptyValues(
                    today: now, subjectId: defaultSubjectId, topicId: defaultTopicId))
    }

    private var validation: TestResultForm.Validation {
        TestResultForm.validate(values, today: today, calendar: calendar)
    }

    private var errors: [TestResultForm.Field: String] {
        guard isSubmitted, case .invalid(let errors) = validation else { return [:] }
        return errors
    }

    private var resolved: TestResultForm.Values { TestResultForm.resolveBlank(values) }

    var body: some View {
        NavigationStack {
            Form {
                subjectSection
                sourceSection
                countsSection
                dateAndPreviewSection
                if editing != nil { deleteSection }
            }
            .analysisFormStyle()
            .navigationTitle(editing == nil ? "Test ekle" : "Testi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", action: onClose).accessibilityIdentifier("analysis.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("analysis.save")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("analysis.testSheet")
        .confirmationDialog(
            AnalysisSheetText.deleteConfirmTitle, isPresented: $showsDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: Bölümler

    private var subjectSection: some View {
        Section {
            Picker("Ders", selection: subjectBinding) {
                Text("Ders seç").tag(UUID?.none)
                ForEach(data.subjects) { subject in
                    Text("\(subject.exam.rawValue) · \(subject.name)").tag(UUID?.some(subject.id))
                }
            }
            .accessibilityIdentifier("analysis.field.subject")
            FieldErrorText(text: errors[.subject])

            Picker("Konu", selection: $values.topicId) {
                Text("Konu seçilmedi").tag(UUID?.none)
                ForEach(topicsOfSubject) { topic in Text(topic.name).tag(UUID?.some(topic.id)) }
            }
            .disabled(values.subjectId == nil)
            .accessibilityIdentifier("analysis.field.topic")
        }
.analysisRows()
    }

    private var sourceSection: some View {
        Section {
            Picker("Kaynak kitap", selection: $values.source) {
                Text("Kitap yok").tag(TestResultForm.Source.none)
                if let missing = missingBookId {
                    Text("Silinmiş kitap").tag(TestResultForm.Source.book(missing))
                }
                ForEach(data.bookOptions(including: currentBookId)) { book in
                    Text(book.title).tag(TestResultForm.Source.book(book.id))
                }
                Text("Diğer (yaz)").tag(TestResultForm.Source.other)
            }
            .accessibilityIdentifier("analysis.field.source")
            if values.source == .other {
                LabeledContent("Kaynak adı") {
                    TextField("Kaynak adı", text: $values.sourceName, prompt: Text("Okul fasikülü"))
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("analysis.field.sourceName")
                }
                FieldErrorText(text: errors[.sourceName])
            }
            LabeledContent("Kitaptaki yer") {
                TextField("Kitaptaki yer", text: $values.label, prompt: Text("Test 12 / s. 45"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("analysis.field.label")
            }
            FieldErrorText(text: errors[.label])
        }
.analysisRows()
    }

    private var countsSection: some View {
        Section {
            numberField("Soru sayısı", id: "questionCount", text: $values.questionCount, error: errors[.questionCount])
            numberField("Doğru", id: "correct", text: $values.correct, error: errors[.correct])
            numberField("Yanlış", id: "wrong", text: $values.wrong, error: errors[.wrong])
            numberField(
                "Boş", id: "blank", text: blankBinding, error: errors[.blank], isEnabled: !values.blankAuto)
            Toggle("Boşu otomatik hesapla", isOn: blankAutoBinding)
                .accessibilityIdentifier("analysis.field.blankAuto")
            Text(previewText)
                .fokusTextStyle(.numeralSM)
                .foregroundStyle(.fkLabel)
                .accessibilityIdentifier("analysis.preview")
            FieldErrorText(text: saveError)
        }
.analysisRows()
    }

    private var dateAndPreviewSection: some View {
        Section {
            DatePicker(
                "Tarih", selection: $values.date, in: ...today, displayedComponents: .date
            )
            .environment(\.locale, AnalysisFormat.locale)
            .accessibilityIdentifier("analysis.field.date")
            FieldErrorText(text: errors[.date])
        }
.analysisRows()
    }

    private var deleteSection: some View {
        Section {
            Button("Testi sil", role: .destructive) { showsDeleteConfirm = true }
                .accessibilityIdentifier("analysis.delete")
        }
.analysisRows()
    }

    private func numberField(
        _ title: String, id: String, text: Binding<String>, error: String?, isEnabled: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            LabeledContent(title) {
                TextField(title, text: text, prompt: Text("0"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .fokusTextStyle(.numeralSM)
                    .disabled(!isEnabled)
                    .accessibilityIdentifier("analysis.field.\(id)")
            }
            FieldErrorText(text: error)
        }
    }

    // MARK: Bağlamalar ve türetilmiş değerler

    private var subjectBinding: Binding<UUID?> {
        Binding(
            get: { values.subjectId },
            set: { newValue in
                guard newValue != values.subjectId else { return }
                values.subjectId = newValue
                values.topicId = nil
            })
    }

    private var blankBinding: Binding<String> {
        Binding(get: { values.blankAuto ? resolved.blank : values.blank }, set: { values.blank = $0 })
    }

    private var blankAutoBinding: Binding<Bool> {
        Binding(
            get: { values.blankAuto },
            set: { isOn in values = isOn ? with(values) { $0.blankAuto = true } : with(resolved) { $0.blankAuto = false } })
    }

    private func with(_ values: TestResultForm.Values, _ change: (inout TestResultForm.Values) -> Void)
        -> TestResultForm.Values
    {
        var copy = values
        change(&copy)
        return copy
    }

    private var topicsOfSubject: [Topic] {
        values.subjectId.flatMap { data.topicsBySubject[$0] } ?? []
    }

    private var currentBookId: UUID? {
        if case .book(let id) = values.source { return id }
        return nil
    }

    private var missingBookId: UUID? {
        guard let id = currentBookId, data.booksById[id] == nil else { return nil }
        return id
    }

    private var previewText: String {
        guard let counts = TestResultForm.previewCounts(values) else { return "Net: —" }
        let net = TestsCalc.computeNet(correct: counts.correct, wrong: counts.wrong)
        let accuracy = TestsCalc.accuracyOf(correct: counts.correct, wrong: counts.wrong, blank: counts.blank)
        return "Net: \(AnalysisFormat.formatNet(net)) · Başarı \(AnalysisFormat.formatPercent(accuracy))"
    }

    // MARK: Eylemler

    private func save() {
        isSubmitted = true
        guard case .valid(let input) = validation else { return }
        do {
            let repository = AnalysisRepository(context: modelContext)
            if let editing {
                try repository.updateResult(editing, with: input, calendar: calendar)
            } else {
                try repository.addResult(input, calendar: calendar)
            }
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }

    private func delete() {
        guard let editing else { return }
        do {
            try AnalysisRepository(context: modelContext).deleteResult(editing)
            onClose()
        } catch {
            saveError = AnalysisSheetText.saveFailed
        }
    }
}
