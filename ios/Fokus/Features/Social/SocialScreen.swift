import FokusDesign
import SwiftUI

/// Sosyal modülü — yer tutucu. Arkadaşlar ve odak odaları kendi oturumunda yapılacak.
struct SocialScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Sosyal", eyebrow: "Arkadaşlar")
                LineSection {
                    LineRow("Yakında", subtitle: "Sosyal modülü kendi oturumunda yapılacak.")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.social")
    }
}

#Preview {
    SocialScreen().fokusTheme()
}
