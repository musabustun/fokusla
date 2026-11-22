import FokusDesign
import FokusDomain
import SwiftUI

/// Devam eden kitaplar: en fazla 3 kitap, ilerleme metni ve çubuğu. Web `BooksCard`. Yalnızca okur.
struct TodayBooksSection: View {
    let books: [BooksCalc.BookSummary]

    var body: some View {
        TodaySection("Kitaplar", identifier: "today.books") {
            if !books.isEmpty {
                TodaySectionLink(section: .books) { TodayLinkLabel(title: "Tümü") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.books.open")
            }
        } content: {
            if books.isEmpty {
                EmptyStateView(
                    "Devam eden kitap yok", systemImage: "books.vertical",
                    message: "Kitaplarını ekle, nereye kadar geldiğini buradan takip et."
                ) {
                    TodaySectionLink(section: .books) { Text("Kitap ekle") }
                        .buttonStyle(.fokusSecondary)
                        .fixedSize()
                        .accessibilityIdentifier("today.books.add")
                }
                .accessibilityIdentifier("today.books.empty")
            } else {
                ForEach(books) { row($0) }
            }
        }
    }

    private func progressText(_ summary: BooksCalc.BookSummary) -> String {
        let book = summary.book
        if summary.ratio != nil, let total = book.totalUnits {
            return BooksFormat.progressCount(book.unit, reached: summary.reachedUnit, total: total)
        }
        if summary.reachedUnit <= 0 { return "Başlanmadı" }
        return BooksFormat.position(book.unit, reached: summary.reachedUnit)
    }

    private func row(_ summary: BooksCalc.BookSummary) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.md) {
                Text(summary.book.title).fokusTextStyle(.callout).foregroundStyle(.fkLabel).lineLimit(2)
                Spacer(minLength: FokusSpacing.sm)
                if let ratio = summary.ratio {
                    Text(BooksFormat.percent(ratio)).fokusTextStyle(.numeralSM).foregroundStyle(.fkLabel)
                }
            }
            Text(progressText(summary)).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel).monospacedDigit()
            if let ratio = summary.ratio { ProgressBar(value: ratio, size: .small) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FokusSpacing.md)
        .overlay(alignment: .bottom) { Divider().overlay(.fkSeparator) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.book.title)
        .accessibilityValue(
            [summary.ratio.map { "yüzde \(Int(($0 * 100).rounded()))" }, progressText(summary)]
                .compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("today.book.\(summary.book.title)")
    }
}
