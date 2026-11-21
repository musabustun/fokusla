import FokusDesign
import FokusDomain
import SwiftUI

/// "Bitir" sonrası oturum özeti.
struct FocusSummarySheet: View {
    let stats: FocusCalc.FocusSessionStats
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            Text("Oturum özeti")
                .fokusTextStyle(.title2)
                .foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
            Metric(label: "Bu oturumda odak", value: FocusFormat.clock(stats.focusMs), size: .xl, tone: .accent)
                .accessibilityIdentifier("focus.summary.focus")
            LineSection {
                LineRow("Toplam odak", value: FocusFormat.durationText(stats.focusMs))
                LineRow("Mola sayısı", value: stats.breakCount.formatted(.number.locale(Locale(identifier: "tr_TR"))))
                LineRow("Toplam mola", value: FocusFormat.durationText(stats.breakMs))
            }
            Spacer(minLength: 0)
            Button("Tamam", action: onClose)
                .buttonStyle(.fokusPrimary)
                .accessibilityIdentifier("focus.summary.done")
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        // Üstte sistem sürükleme tutamacına yer bırakır.
        .padding(.top, FokusSpacing.xxl + FokusSpacing.lg)
        .padding(.bottom, FokusSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.fkBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.summary")
    }
}

#Preview("Özet — koyu") {
    FocusSummarySheet(
        stats: FocusCalc.FocusSessionStats(
            focusMs: 3_905_000, breakMs: 600_000, focusCount: 2, breakCount: 1,
            averageFocusMs: 0, averageBreakMs: 0),
        onClose: {}
    )
    .fokusTheme()
    .preferredColorScheme(.dark)
}
