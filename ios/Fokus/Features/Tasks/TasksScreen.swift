import FokusDesign
import SwiftUI

/// Görevler modülü — yer tutucu. Rutinler ve ödevler kendi oturumunda yapılacak.
struct TasksScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Görevler", eyebrow: "Rutinler ve ödevler")
                LineSection {
                    LineRow("Yakında", subtitle: "Görevler modülü kendi oturumunda yapılacak.")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.tasks")
    }
}

#Preview {
    TasksScreen().fokusTheme()
}
