import FokusDesign
import SwiftUI

/// Kitaplar modülü — yer tutucu. Kitap takibi kendi oturumunda yapılacak.
struct BooksScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Kitaplar", eyebrow: "Takip")
                LineSection {
                    LineRow("Yakında", subtitle: "Kitaplar modülü kendi oturumunda yapılacak.")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.books")
    }
}

#Preview {
    BooksScreen().fokusTheme()
}
