import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "books")

/// "İlerleme gir" sayfası (web `ProgressSheet`): kitapta nereye kadar gelindiğini (+ opsiyonel not) kaydeder.
struct BookProgressSheet: View {
    let summary: BooksCalc.BookSummary

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fokusPalette) private var palette

    @State private var reached: String
    @State private var note = ""
    @State private var errorMessage: String?
    @FocusState private var isReachedFocused: Bool

    init(summary: BooksCalc.BookSummary) {
        self.summary = summary
        _reached = State(initialValue: summary.reachedUnit > 0 ? String(summary.reachedUnit) : "")
    }

    private var book: BookSnapshot { summary.book }
    private var parsed: Int? { BooksInput.parseReachedUnit(reached) }
    private var rowBackground: Color { FokusColor.color(.surface, palette: palette) }

    private var warnings: [BooksInput.ProgressWarning] {
        BooksInput.progressWarnings(
            value: parsed, currentReached: summary.reachedUnit, total: BooksCalc.knownTotal(book))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0", text: $reached)
                        .keyboardType(.numberPad)
                        .focused($isReachedFocused)
                        .fokusTextStyle(.numeral)
                        .accessibilityLabel("Ulaştığın \(BooksFormat.unitNoun(book.unit))")
                        .accessibilityIdentifier("book.progress.reached")
                        .listRowBackground(rowBackground)
                } header: {
                    Text("Ulaştığın \(BooksFormat.unitNoun(book.unit))")
                        .fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                } footer: {
                    VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                        if let total = BooksCalc.knownTotal(book) {
                            Text("Toplam: \(BooksFormat.number(total))")
                                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                        }
                        ForEach(warnings, id: \.message) { warning in
                            Label(warning.message, systemImage: "exclamationmark.triangle")
                                .fokusTextStyle(.footnote).foregroundStyle(.fkWarning)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("book.progress.hint")
                }
                Section {
                    TextField("İsteğe bağlı", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("book.progress.note")
                        .listRowBackground(rowBackground)
                } header: {
                    Text("Not").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                            .accessibilityIdentifier("book.progress.error")
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.fkBackground)
            .navigationTitle("İlerleme gir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }.accessibilityIdentifier("book.progress.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).fontWeight(.semibold)
                        .accessibilityIdentifier("book.progress.save")
                }
            }
            .task { isReachedFocused = true }
        }
        .accessibilityIdentifier("book.progress")
    }

    private func save() {
        guard let value = parsed else {
            errorMessage = BookValidationError.invalidReachedUnit.message
            isReachedFocused = true
            return
        }
        do {
            try BooksRepository(context: modelContext).addProgress(
                bookId: book.id, reachedUnit: value, note: note)
            dismiss()
        } catch let error as BookValidationError {
            errorMessage = error.message
        } catch {
            logger.error("İlerleme kaydedilemedi: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Kaydedilemedi. Lütfen tekrar dene."
        }
    }
}
