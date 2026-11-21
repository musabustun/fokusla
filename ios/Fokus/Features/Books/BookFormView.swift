import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "books")

/// Kitap ekle / düzenle sayfası (web `BookFormSheet`). Doğrulama `BooksInput` + `BooksRepository`.
struct BookFormView: View {
    /// Düzenlenecek kitap; `nil` → yeni kitap.
    let book: Book?
    let subjectGroups: [BookSubjectGroup]
    /// Kayıttan sonra (oluşturulan/güncellenen kitabın kimliğiyle) çağrılır.
    var onSaved: (UUID) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fokusPalette) private var palette

    @State private var title: String
    @State private var publisher: String
    @State private var subjectId: UUID?
    @State private var kind: BookKind
    @State private var unit: BookUnit
    @State private var total: String
    @State private var errorMessage: String?

    init(book: Book?, subjectGroups: [BookSubjectGroup], onSaved: @escaping (UUID) -> Void = { _ in }) {
        self.book = book
        self.subjectGroups = subjectGroups
        self.onSaved = onSaved
        _title = State(initialValue: book?.title ?? "")
        _publisher = State(initialValue: book?.publisher ?? "")
        _subjectId = State(initialValue: book?.subjectId)
        _kind = State(initialValue: book?.kind ?? .questionBank)
        _unit = State(initialValue: book?.unit ?? .test)
        _total = State(initialValue: book?.totalUnits.map(String.init) ?? "")
    }

    private var isEditing: Bool { book != nil }
    private var rowBackground: Color { FokusColor.color(.surface, palette: palette) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ör. TYT Matematik Soru Bankası", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("book.form.title")
                        .listRowBackground(rowBackground)
                } header: {
                    header("Kitap adı")
                }
                Section {
                    TextField("İsteğe bağlı", text: $publisher)
                        .accessibilityIdentifier("book.form.publisher")
                        .listRowBackground(rowBackground)
                } header: {
                    header("Yayınevi")
                }
                Section {
                    Picker("Ders", selection: $subjectId) {
                        Text("Ders seçilmedi").tag(UUID?.none)
                        ForEach(subjectGroups) { group in
                            Section(group.exam.rawValue) {
                                ForEach(group.subjects) { subject in
                                    Text(subject.name).tag(UUID?.some(subject.id))
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("book.form.subject")
                    .listRowBackground(rowBackground)
                    Picker("Tür", selection: $kind) {
                        ForEach(BookKind.formOrder, id: \.self) { kind in
                            Text(BooksFormat.kindLabel(kind)).tag(kind)
                        }
                    }
                    .accessibilityIdentifier("book.form.kind")
                    .listRowBackground(rowBackground)
                } header: {
                    header("Ders ve tür")
                }
                Section {
                    Picker("İlerleme birimi", selection: $unit) {
                        ForEach(BookUnit.formOrder, id: \.self) { unit in
                            Text(BooksFormat.unitLabel(unit)).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("book.form.unit")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    TextField("Toplam", text: $total)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("book.form.total")
                        .listRowBackground(rowBackground)
                } header: {
                    header("İlerleme birimi ve toplam")
                } footer: {
                    Text("Toplam \(BooksFormat.unitNoun(unit)) sayısı. Bilmiyorsan boş bırak.")
                        .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                            .accessibilityIdentifier("book.form.error")
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.fkBackground)
            .navigationTitle(isEditing ? "Kitabı düzenle" : "Kitap ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }.accessibilityIdentifier("book.form.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).fontWeight(.semibold)
                        .accessibilityIdentifier("book.form.save")
                }
            }
        }
        .accessibilityIdentifier("book.form")
    }

    private func header(_ text: String) -> some View {
        Text(text).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
    }

    private func save() {
        let parsedTotal: Int?
        switch BooksInput.parseTotal(total) {
        case .unknown: parsedTotal = nil
        case .value(let value): parsedTotal = value
        case .invalid:
            errorMessage = BookValidationError.invalidTotal.message
            return
        }
        let input = BookInput(
            title: title, publisher: publisher, kind: kind, subjectId: subjectId, unit: unit,
            totalUnits: parsedTotal)
        let repository = BooksRepository(context: modelContext)
        do {
            let saved = try book.map { try repository.update($0, with: input) } ?? repository.create(input)
            onSaved(saved.id)
            dismiss()
        } catch let error as BookValidationError {
            errorMessage = error.message
        } catch {
            logger.error("Kitap kaydedilemedi: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Kitap kaydedilemedi. Lütfen tekrar dene."
        }
    }
}

extension BookKind {
    /// Formdaki sıralama (web `BOOK_KINDS`).
    static let formOrder: [BookKind] = [.questionBank, .lecture, .practiceExam, .other]
}

extension BookUnit {
    /// Formdaki sıralama (web `BOOK_UNITS`).
    static let formOrder: [BookUnit] = [.test, .page, .section]
}
