import FokusDesign
import SwiftUI

/// Renk teması seçimi (web `ThemeStep`): seçim hemen tüm ekrana uygulanır ve kalıcıdır
/// (`@AppStorage(FokusThemeKeys.palette)`); Ayarlar'dan sonra değiştirilebilir.
struct ThemeStep: View {
    @AppStorage(FokusThemeKeys.palette) private var paletteRaw = FokusPalette.default.rawValue

    let onNext: () -> Void
    let onBack: () -> Void

    private var palette: Binding<FokusPalette> {
        Binding(
            get: { FokusPalette(rawValue: paletteRaw) ?? .default },
            set: { paletteRaw = $0.rawValue }
        )
    }

    var body: some View {
        OnboardingStepLayout(
            title: "Temanı seç",
            subtitle: "İstediğin zaman Ayarlar'dan değiştirebilirsin.",
            brand: false
        ) {
            PalettePicker(selection: palette)
        } actions: {
            Button("Devam", action: onNext)
                .buttonStyle(.fokusPrimary)
                .accessibilityIdentifier("onboarding.continue")
            Button("Geri", action: onBack)
                .buttonStyle(.plain)
                .font(.headline)
                .foregroundStyle(.fkSecondaryLabel)
                .frame(minHeight: fokusMinTapTarget)
                .accessibilityIdentifier("onboarding.back")
        }
    }
}

#Preview {
    ThemeStep(onNext: {}, onBack: {}).fokusTheme()
}
