import AuthenticationServices
import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "onboarding")

/// Onboarding akışı: Hoş geldin → YKS alanı → Temanı seç → Apple ile Giriş.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var field: YksField?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStep(onNext: { go(to: .field) })
            case .field:
                FieldStep(selection: $field, onNext: advance, onBack: goBack)
            case .theme:
                ThemeStep(onNext: advance, onBack: goBack)
            case .account:
                AccountStep(
                    errorMessage: errorMessage,
                    onCompletion: handleSignIn,
                    onSkip: { complete(appleUserId: nil, displayName: nil) },
                    onBack: goBack
                )
            }
        }
        .background(.fkBackground)
    }

    private func advance() {
        if let next = step.next() { go(to: next) }
    }

    private func goBack() {
        errorMessage = nil
        if let previous = step.previous() { go(to: previous) }
    }

    private func go(to newStep: OnboardingStep) {
        if reduceMotion {
            step = newStep
        } else {
            withAnimation(.easeInOut(duration: FokusMotion.enter)) { step = newStep }
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch AppleAuthService.identity(from: result) {
        case let .success(identity):
            complete(appleUserId: identity.userId, displayName: identity.displayName)
        case let .failure(error):
            guard let message = error.userMessage else { return } // iptal: sessizce kal
            errorMessage = message
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private func complete(appleUserId: String?, displayName: String?) {
        guard let field else { return }
        do {
            try ProfileRepository(context: modelContext).completeOnboarding(
                field: field, appleUserId: appleUserId, displayName: displayName
            )
        } catch {
            logger.error("Onboarding kaydedilemedi: \(error.localizedDescription, privacy: .public)")
            let message = "Kaydedilemedi. Lütfen tekrar dene."
            errorMessage = message
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

#Preview {
    OnboardingView()
        .fokusTheme()
        .modelContainer(PreviewSupport.emptyContainer())
}
