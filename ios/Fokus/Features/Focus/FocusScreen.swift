import FokusDesign
import SwiftUI

/// Odak modülü — yer tutucu. Kronometre kendi oturumunda yapılacak.
struct FocusScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Odak", eyebrow: "Kronometre")
                LineSection {
                    LineRow("Yakında", subtitle: "Odak modülü kendi oturumunda yapılacak.")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.focus")
    }
}

#Preview {
    FocusScreen().fokusTheme()
}
