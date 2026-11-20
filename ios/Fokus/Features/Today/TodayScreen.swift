import FokusDesign
import SwiftUI

/// Bugün modülü — yer tutucu. Özet kartları kendi oturumunda yapılacak.
struct TodayScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var dateEyebrow: String {
        Date.now.formatted(
            Date.FormatStyle().weekday(.wide).day().month(.wide).locale(Locale(identifier: "tr_TR"))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Bugün", eyebrow: dateEyebrow)
                LineSection {
                    LineRow("Yakında", subtitle: "Bugün modülü kendi oturumunda yapılacak.")
                }
                // iPhone'da Kitaplar ve Sosyal tab bar'da yok; buradan açılır (web Bugün kısayolları).
                if horizontalSizeClass == .compact {
                    LineSection("Kısayollar") {
                        shortcut(.books)
                        shortcut(.social)
                    }
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.today")
    }

    private func shortcut(_ section: AppSection) -> some View {
        NavigationLink(value: section) {
            LineRow(section.title) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.fkTertiaryLabel)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.shortcut.\(section.rawValue)")
    }
}

#Preview {
    NavigationStack { TodayScreen() }.fokusTheme()
}
