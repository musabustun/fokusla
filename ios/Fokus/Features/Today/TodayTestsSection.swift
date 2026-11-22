import FokusDesign
import FokusDomain
import SwiftUI

/// Son testler: son 7 günün net/doğruluk/soru özeti, bugün çözülen soru ve en zayıf konular.
/// Web `TestsCard`. Yalnızca okur.
struct TodayTestsSection: View {
    struct WeakRow: Identifiable, Equatable {
        let id: UUID
        let topic: String
        let subject: String?
        let accuracy: Double
    }

    let recent: TodayCalc.RecentTests
    let weakRows: [WeakRow]

    var body: some View {
        TodaySection("Son testler", identifier: "today.tests") {
            if recent.allTimeCount > 0 {
                TodaySectionLink(section: .analysis) { TodayLinkLabel(title: "Analiz") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.tests.open")
            }
        } content: {
            if recent.allTimeCount == 0 {
                empty
            } else {
                summary
                if !weakRows.isEmpty { weak }
            }
        }
    }

    private var empty: some View {
        EmptyStateView(
            "Henüz test girmedin", systemImage: "chart.bar",
            message: "İlk deneme sonucunu Analiz'e ekle; netlerin burada belirsin."
        ) {
            TodaySectionLink(section: .analysis) { Text("Analiz'e git") }
                .buttonStyle(.fokusSecondary)
                .fixedSize()
                .accessibilityIdentifier("today.tests.add")
        }
        .accessibilityIdentifier("today.tests.empty")
    }

    private var summary: some View {
        let window = recent.window
        return VStack(alignment: .leading, spacing: FokusSpacing.md) {
            HStack(alignment: .top, spacing: FokusSpacing.lg) {
                stat("Net", value: window.testCount == 0 ? "—" : AnalysisFormat.formatNet(window.net))
                stat("Doğruluk", value: window.totalQuestions == 0 ? "—" : AnalysisFormat.formatPercent(window.accuracy))
                stat("Soru", value: AnalysisFormat.formatCount(window.totalQuestions))
            }
            Text(caption)
                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                .accessibilityIdentifier("today.tests.caption")
        }
        .padding(.vertical, FokusSpacing.lg)
        .overlay(alignment: .bottom) { Divider().overlay(.fkSeparator) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.tests.summary")
    }

    private var caption: String {
        let window = recent.window
        let range = window.testCount == 0
            ? "Son 7 günde test yok"
            : "Son 7 gün · \(AnalysisFormat.formatCount(window.testCount)) test"
        return recent.todayQuestions > 0
            ? "\(range) · bugün \(AnalysisFormat.formatQuestionCount(recent.todayQuestions))"
            : range
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text(label).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            Text(value)
                .fokusTextStyle(.numeralLG)
                .foregroundStyle(.fkLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value == "—" ? "henüz yok" : value)
    }

    private var weak: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("En zayıf konular")
                .fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                .padding(.top, FokusSpacing.lg).padding(.bottom, FokusSpacing.xs)
                .accessibilityAddTraits(.isHeader)
            ForEach(weakRows) { row in
                LineRow(row.topic, subtitle: row.subject, value: "\(AnalysisFormat.formatPercent(row.accuracy)) doğru")
                    .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("today.tests.weak")
    }
}
