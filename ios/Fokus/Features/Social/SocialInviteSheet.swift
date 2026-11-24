import FokusData
import FokusDesign
import SwiftUI

/// Sistemden gelen daveti, hangi ekranda olursan ol "Davet" sayfasında gösterir.
private struct SocialInviteHost: ViewModifier {
    @Environment(\.socialService) private var social
    @State private var inbox = SocialInviteInbox.shared

    func body(content: Content) -> some View {
        content.background {
            Color.clear.sheet(item: $inbox.pending) { pending in
                if let social { SocialInviteSheet(social: social, invite: pending.invite) }
            }
        }
    }
}

extension View {
    /// Kabuk köküne uygulanır (onboarding bittikten sonra).
    func socialInviteHost() -> some View { modifier(SocialInviteHost()) }
}

/// Davet onayı: giriş ya da kullanıcı adı eksikse önce onu tamamlatır, sonra kabul ettirir.
struct SocialInviteSheet: View {
    let social: any SocialService
    let invite: SocialInvite

    @Environment(\.dismiss) private var dismiss
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var outcome: SocialInviteOutcome?

    var body: some View {
        SocialSheetScaffold(
            title: "Fokus daveti", description: nil, identifier: "social.invite",
            cancelTitle: outcome == nil ? "Vazgeç" : "Kapat"
        ) {
            switch social.snapshot.status {
            case .ready: ready
            case .loading:
                Text("Yükleniyor…").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            case .signedOut: SocialGateView(social: social)
            case .needsUsername: SocialUsernameSetupView(social: social)
            case .iCloudUnavailable, .unreachable: SocialUnavailableView(social: social)
            }
        }
        .task { if social.snapshot.status != .ready { await social.refresh() } }
    }

    @ViewBuilder private var ready: some View {
        if let outcome {
            Text(message(outcome))
                .fokusTextStyle(.title2).foregroundStyle(.fkLabel)
                .accessibilityIdentifier("social.invite.done")
            Button("Tamam") { dismiss() }.buttonStyle(.fokusPrimary)
        } else {
            Text("Bir davet aldın")
                .fokusTextStyle(.title2).foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
            Text("Kabul edersen davet eden kişi (oda ise odadakiler) kullanıcı adını, odak durumunu ve bugünkü çalışma süreni görür; sen de onunkini. İstediğin an çıkabilirsin.")
                .fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
            if let errorMessage { SocialErrorText(message: errorMessage, identifier: "social.invite.error") }
            Button("Kabul et", action: accept)
                .buttonStyle(.fokusPrimary)
                .disabled(isBusy)
                .accessibilityIdentifier("social.invite.accept")
        }
    }

    private func message(_ outcome: SocialInviteOutcome) -> String {
        switch outcome {
        case let .friend(username): "@\(username) artık arkadaşın."
        case let .room(name): "“\(name)” odasındasın."
        }
    }

    private func accept() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do { outcome = try await social.acceptInvite(invite) } catch {
                errorMessage = SocialError.message(for: error)
            }
        }
    }
}

/// iCloud yok ya da hiç yüklenemedi.
struct SocialUnavailableView: View {
    let social: any SocialService
    @State private var isBusy = false

    private var isICloud: Bool { social.snapshot.status == .iCloudUnavailable }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Text(isICloud ? "iCloud'a giriş yap" : "Şu an yüklenemedi")
                .fokusTextStyle(.title1).foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
            Text(isICloud
                ? "Sosyal, arkadaşlarınla yalnızca iCloud üzerinden eşleşir. Ayarlar › Apple Hesabı'ndan iCloud'a giriş yapıp tekrar dene. Fokus'un geri kalanı iCloud olmadan da çalışır."
                : "İnternet bağlantını kontrol edip tekrar dene.")
                .fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
            Button("Tekrar dene") {
                isBusy = true
                Task {
                    await social.refresh()
                    isBusy = false
                }
            }
            .buttonStyle(.fokusSecondary)
            .disabled(isBusy)
            .accessibilityIdentifier("social.unavailable.retry")
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .socialContainer("social.unavailable")
    }
}

extension SocialError {
    /// Her hata için gösterilecek Türkçe mesaj.
    static func message(for error: any Error) -> String {
        (error as? SocialError ?? SocialError(.unknown)).userMessage
    }
}
