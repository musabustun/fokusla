import AuthenticationServices
import FokusData
import FokusDesign
import SwiftData
import SwiftUI

/// Hesap bölümü (web `AccountSection`): Apple ile Giriş / çıkış / hesabı sil. Giriş opsiyoneldir.
struct SettingsAccountSection: View {
    let profile: UserProfile?
    @Binding var sheet: SettingsSheet?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    private var isSignedIn: Bool { profile?.appleUserId != nil }

    var body: some View {
        LineSection("Hesap", footer: footer) {
            if isSignedIn {
                LineRow("Apple hesabı", subtitle: profile?.displayName, value: "Bağlı")
                    .accessibilityIdentifier("settings.account.linked")
                SettingsButtonRow(title: "Çıkış yap", action: signOut)
                    .accessibilityIdentifier("settings.account.signOut")
                SettingsButtonRow(title: "Hesabı sil", isDestructive: true) { sheet = .deleteAccount }
                    .accessibilityIdentifier("settings.account.delete")
            } else {
                VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { $0.requestedScopes = [.fullName] },
                        onCompletion: handleSignIn
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 48)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("settings.account.signIn")
                    if let errorMessage { SettingsMessage(text: errorMessage, isError: true) }
                }
                .padding(.vertical, FokusSpacing.md)
            }
        }
    }

    private var footer: String {
        isSignedIn
            ? "Çıkış yapınca iCloud eşitlemesi kapanır; verilerin cihazında kalır."
            : "Giriş yapmadan da tüm özellikler cihazında çalışır."
    }

    private func handleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch AppleAuthService.identity(from: result) {
        case let .success(identity):
            do {
                try AccountService(context: modelContext, sync: syncService).link(identity)
                errorMessage = nil
            } catch {
                errorMessage = AppleSignInError.failed(error.localizedDescription).userMessage
            }
        case let .failure(error):
            errorMessage = error.userMessage
        }
    }

    private func signOut() {
        do {
            try AccountService(context: modelContext, sync: syncService).signOut()
        } catch {
            errorMessage = "Çıkış yapılamadı. Lütfen tekrar dene."
        }
    }
}
