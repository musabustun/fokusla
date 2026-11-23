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
    /// Barkod akışından gelen ön doldurma (yalnızca yeni kitapta).
    let prefill: BookFormPrefill?

    private static let invalidBarcodeMessage = "Geçerli bir barkod değil. 13 haneli numarayı kontrol et."

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fokusPalette) private var palette

    @State private var title: String
    @State private var publisher: String
    @State private var subjectId: UUID?
    @State private var kind: BookKind
    @State private var unit: BookUnit
    @State private var total: String
    @State private var barcode: String
    @State private var errorMessage: String?

    init(
        book: Book?, subjectGroups: [BookSubjectGroup], prefill: BookFormPrefill? = nil,
        onSaved: @escaping (UUID) -> Void = { _ in }
    ) {
        self.book = book
        self.subjectGroups = subjectGroups
        self.onSaved = onSaved
        let prefill = book == nil ? prefill : nil
        self.prefill = prefill
        _title = State(initialValue: book?.title ?? prefill?.title ?? "")
        _publisher = State(initialValue: book?.publisher ?? prefill?.publisher ?? "")
        _subjectId = State(initialValue: book?.subjectId ?? prefill?.subjectId)
        _kind = State(initialValue: book?.kind ?? prefill?.kind ?? .questionBank)
        _unit = State(initialValue: book?.unit ?? prefill?.unit ?? .test)
        _total = State(initialValue: (book?.totalUnits ?? prefill?.totalUnits).map(String.init) ?? "")
        _barcode = State(initialValue: book?.barcode ?? prefill?.barcode ?? "")
    }

    private var isEditing: Bool { book != nil }
    private var rowBackground: Color { FokusColor.color(.surface, palette: palette) }

    var body: some View {
        NavigationStack {
            Form {
                if let notice = prefill?.notice {
                    Section {
                        Label(notice, systemImage: "info.circle")
                            .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                            .accessibilityIdentifier("book.form.notice")
                    }
                    .listRowBackground(rowBackground)
                }
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
                Section {
                    TextField("İsteğe bağlı", text: $barcode)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Barkod")
                        .accessibilityIdentifier("book.form.barcode")
                        .listRowBackground(rowBackground)
                } header: {
                    header("Barkod")
                }
                if let sections = prefill?.sections, !sections.isEmpty {
                    Section {
                        ForEach(sections, id: \.order) { section in
                            VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                                Text(section.title).fokusTextStyle(.body).foregroundStyle(.fkLabel)
                                if let range = BooksFormat.sectionRange(
                                    unit, start: section.startUnit, end: section.endUnit)
                                {
                                    Text(range).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        header("Bölümler (\(sections.count))")
                    }
                    .accessibilityIdentifier("book.form.sections")
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
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalizedBarcode: String?
        if !trimmedBarcode.isEmpty {
            guard let normalized = Barcode.normalize(trimmedBarcode) else {
                errorMessage = Self.invalidBarcodeMessage
                return
            }
            normalizedBarcode = normalized
        }
        let input = BookInput(
            title: title, publisher: publisher, kind: kind, subjectId: subjectId, unit: unit,
            totalUnits: parsedTotal, barcode: normalizedBarcode,
            libraryKey: book?.libraryKey ?? prefill?.libraryKey)
        let repository = BooksRepository(context: modelContext)
        do {
            let saved: Book
            if let book {
                saved = try repository.update(book, with: input)
            } else {
                saved = try repository.create(input)
                if let sections = prefill?.sections, !sections.isEmpty {
                    try repository.replaceSections(sections, for: saved)
                }
            }
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
