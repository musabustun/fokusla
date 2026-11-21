import FokusDesign
import SwiftUI

/// Hoş geldin adımı.
struct WelcomeStep: View {
    let onNext: () -> Void

    private static let highlights: [(title: String, text: String)] = [
        ("Odaklan", "Kronometreyle çalış, molalarını ve günlük toplamını gör."),
        ("Analiz et", "Konu konu testlerini, doğru-yanlışlarını ve netlerini takip et."),
        ("Planla", "Kitaplarında nerede kaldığını, rutinlerini ve ödevlerini tut."),
    ]

    var body: some View {
        OnboardingStepLayout(
            title: "Fokus'a hoş geldin",
            subtitle: "YKS hazırlığın için ücretsiz, reklamsız çalışma takibi. Verilerin cihazında kalır.",
            brand: true
        ) {
            LineSection {
                ForEach(Self.highlights, id: \.title) { item in
                    LineRow(item.title, subtitle: item.text)
                        .accessibilityElement(children: .combine)
                }
            }
        } actions: {
            Button("Başla", action: onNext)
                .buttonStyle(.fokusPrimary)
                .accessibilityIdentifier("onboarding.start")
        }
    }
}

#Preview {
    WelcomeStep(onNext: {}).fokusTheme()
}
