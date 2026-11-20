import AuthenticationServices
import FokusDesign
import SwiftUI

/// Apple ile Giriş adımı (opsiyonel; "Şimdilik atla" her zaman mümkün).
struct AccountStep: View {
    @Environment(\.colorScheme) private var colorScheme

    let errorMessage: String?
    let onCompletion: (Result<ASAuthorization, any Error>) -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStepLayout(
            title: "Verilerini yedekle",
            subtitle: "Apple ile giriş yaparsan verilerini iCloud üzerinden iPhone ile iPad'in arasında eşitleyebilirsin. Giriş zorunlu değil; her şey cihazında çalışır.",
            brand: false
        ) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.fkDanger)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("onboarding.error")
            }
        } actions: {
            SignInWithAppleButton(
                .signIn,
                onRequest: { $0.requestedScopes = [.fullName] },
                onCompletion: onCompletion
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())
            .accessibilityIdentifier("onboarding.signInWithApple")
            Button("Şimdilik atla", action: onSkip)
                .buttonStyle(.fokusSecondary)
                .accessibilityIdentifier("onboarding.skip")
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
    AccountStep(errorMessage: nil, onCompletion: { _ in }, onSkip: {}, onBack: {}).fokusTheme()
}
