import FokusDesign
import FokusDomain
import SwiftUI

/// Kitap listesinin tek satırı (web `BookListRow`): başlık, yayınevi, ilerleme · hız,
/// son ilerleme · tahmini bitiş ve ince ilerleme çubuğu; sağda yüzde ya da durum.
struct BookRowView: View {
    let summary: BooksCalc.BookSummary
    let now: Date
    /// iPad'de detayı açık olan kitap (vurgulanır).
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: FokusSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.book.title)
                        .fokusTextStyle(.body).foregroundStyle(.fkLabel)
                        .lineLimit(2)
                    if let publisher = summary.book.publisher {
                        Text(publisher).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
                    }
                    Text(progressLine).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
                    Text(timelineLine).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
                    if let ratio = summary.ratio {
                        ProgressBar(value: ratio, tone: summary.status == .completed ? .success : .accent, size: .small)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: FokusSpacing.sm)
                valueView
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.md)
            .padding(.horizontal, isSelected ? FokusSpacing.sm : 0)
            Divider().overlay(.fkSeparator)
        }
        .background { Rectangle().fill(.fkFill).opacity(isSelected ? 1 : 0) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var isStatusValue: Bool { summary.status == .completed || summary.status == .archived }

    @ViewBuilder private var valueView: some View {
        if isStatusValue {
            Text(BooksFormat.statusLabel(summary.status))
                .fokusTextStyle(.subheadline).fontWeight(.medium)
                .foregroundStyle(summary.status == .completed ? FokusColor(.success) : FokusColor(.secondaryLabel))
        } else if let ratio = summary.ratio {
            Text(BooksFormat.percent(ratio)).fokusTextStyle(.numeralSM).foregroundStyle(.fkLabel)
        }
    }

    /// "34 / 120 test · haftada ~12 test" (hız yoksa yalnızca ilerleme).
    private var progressLine: String {
        let book = summary.book
        return [
            BooksFormat.progressCount(book.unit, reached: summary.reachedUnit, total: book.totalUnits),
            BooksFormat.pace(book.unit, pacePerWeek: summary.weeklyPace),
        ]
        .compactMap { $0 }.joined(separator: " · ")
    }

    /// "Son: 18 Kasım · Bitiş ~9 Ocak"; ilerleme yoksa tür adı + "henüz ilerleme yok".
    private var timelineLine: String {
        guard let last = summary.lastProgressAt else {
            return "\(BooksFormat.kindLabel(summary.book.kind)) · henüz ilerleme yok"
        }
        var parts = ["Son: \(BooksFormat.day(last, now: now))"]
        if summary.status == .inProgress, let days = summary.daysToFinish, days > 0 {
            parts.append("Bitiş ~\(BooksFormat.day(BooksFormat.addDays(now, days), now: now))")
        }
        return parts.joined(separator: " · ")
    }
}
