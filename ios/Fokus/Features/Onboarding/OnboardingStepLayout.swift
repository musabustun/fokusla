import FokusDesign
import SwiftUI

/// Ortak adım düzeni: kaydırılabilir içerik + altta sabit eylemler. iPad'de içerik ~560pt'ye sınırlanır.
struct OnboardingStepLayout<Content: View, Actions: View>: View {
    private static var maxContentWidth: CGFloat { 560 }

    let title: String
    let subtitle: String?
    let brand: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                    if brand {
                        Text("Fokus").fokusTextStyle(.eyebrow).foregroundStyle(.fkAccentInk)
                    }
                    Text(title)
                        .fokusTextStyle(.largeTitle)
                        .foregroundStyle(.fkLabel)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle).font(.body).foregroundStyle(.fkSecondaryLabel)
                    }
                }
                content
            }
            .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.top, FokusSpacing.xxl)
            .padding(.bottom, FokusSpacing.lg)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FokusSpacing.sm) { actions }
                .frame(maxWidth: Self.maxContentWidth)
                .padding(.horizontal, FokusSpacing.screenHorizontal)
                .padding(.vertical, FokusSpacing.md)
                .frame(maxWidth: .infinity)
                .background(.fkBackground)
        }
        .background(.fkBackground)
    }
}
