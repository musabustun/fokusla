import FokusDesign
import SwiftUI

/// Analiz modülü — yer tutucu. Konu/test analizi kendi oturumunda yapılacak.
struct AnalysisScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Analiz", eyebrow: "Testler")
                LineSection {
                    LineRow("Yakında", subtitle: "Analiz modülü kendi oturumunda yapılacak.")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.analysis")
    }
}

#Preview {
    AnalysisScreen().fokusTheme()
}
