import FokusDesign
import FokusDomain
import SwiftUI

/// Test özeti (web `SummaryCard`): net ana rakam; başarı, test ve soru sayısı yardımcı rakamlar.
struct SummarySection: View {
    let title: String
    let summary: TestSummary
    var showsLastTaken = false

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Text(title)
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            Metric(
                label: "Net", value: AnalysisFormat.formatNet(summary.net), size: .xl, tone: .accent)
                .accessibilityIdentifier("analysis.summary.net")
            Divider().overlay(.fkSeparator)
            HStack(alignment: .top, spacing: 0) {
                metric("Başarı", AnalysisFormat.formatPercent(summary.accuracy))
                Divider().overlay(.fkSeparator).padding(.horizontal, FokusSpacing.md)
                metric("Toplam test", AnalysisFormat.formatCount(summary.testCount))
                Divider().overlay(.fkSeparator).padding(.horizontal, FokusSpacing.md)
                metric("Soru", AnalysisFormat.formatCount(summary.totalQuestions))
            }
            .fixedSize(horizontal: false, vertical: true)
            if showsLastTaken {
                Text(lastTakenText)
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkSecondaryLabel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysis.summary")
    }

    private var lastTakenText: String {
        summary.lastTakenAt.map { "Son çözülen: \(AnalysisFormat.formatDate($0))" }
            ?? AnalysisFormat.noResultsText
    }

    private func metric(_ label: String, _ value: String) -> some View {
        Metric(label: label, value: value, size: .md)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
