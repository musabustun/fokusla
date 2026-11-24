import AuthenticationServices
import FokusData
import FokusDesign
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "social")

/// Girişsiz kullanıcıya Sosyal'in ne olduğunu anlatır ve "Apple ile Giriş" ister. Fokus'un geri
/// kalanı girişsiz çalışır; Sosyal ise bir hesap gerektirir.
struct SocialGateView: View {
    let social: any SocialService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    private static let points: [(icon: String, text: String)] = [
        ("timer", "Arkadaşlarının şu an odakta mı, molada mı olduğunu gör."),
        ("person.2", "Paralel odak odalarında aynı anda çalışın."),
        ("lock.shield", "Yalnızca kabul ettiğin kişiler kullanıcı adını ve çalışma süreni görür; ders, test ve kitapların cihazında kalır."),
        ("eye.slash", "Kimse seni arayıp bulamaz; istediğin an kendini gizleyebilirsin."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("Birlikte çalışmak için giriş yap")
                    .fokusTextStyle(.title1)
                    .foregroundStyle(.fkLabel)
                    .accessibilityAddTraits(.isHeader)
                Text("Sosyal, Apple ile Giriş ve bu cihazda açık bir iCloud hesabı gerektirir. Fokus'un geri kalanı girişsiz de tam çalışır.")
                    .fokusTextStyle(.callout)
                    .foregroundStyle(.fkSecondaryLabel)
            }
            VStack(spacing: FokusSpacing.md) {
                if let errorMessage {
                    SocialErrorText(message: errorMessage, identifier: "social.gate.error")
                }
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { $0.requestedScopes = [.fullName] },
                    onCompletion: handleSignIn
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(Capsule())
                .accessibilityIdentifier("social.gate.signIn")
            }
            LineSection {
                ForEach(Self.points, id: \.text) { point in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: FokusSpacing.md) {
                            Image(systemName: point.icon)
                                .font(.body)
                                .foregroundStyle(.fkSecondaryLabel)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(point.text).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                        }
                        .padding(.vertical, FokusSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(.fkSeparator)
                    }
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .socialContainer("social.gate")
    }

    private func handleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch AppleAuthService.identity(from: result) {
        case let .success(identity):
            do {
                try AccountService(context: modelContext, sync: syncService).link(identity)
                errorMessage = nil
            } catch {
                logger.error("Apple bağı kaydedilemedi: \(error.localizedDescription, privacy: .public)")
                errorMessage = AppleSignInError.failed(error.localizedDescription).userMessage
            }
        case let .failure(error):
            errorMessage = error.userMessage
        }
    }
}
