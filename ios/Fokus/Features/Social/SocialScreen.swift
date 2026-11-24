import FokusData
import FokusDesign
import SwiftData
import SwiftUI

/// Sosyal modülü: giriş kapısı → kullanıcı adı → arkadaşlar ve paralel odak odaları.
/// Eşleşme yalnızca CloudKit iledir (docs/social-cloudkit.md). Sahibi: social modülü.
struct SocialScreen: View {
    @Environment(\.socialService) private var social
    @Query(
        filter: #Predicate<UserProfile> { $0.deletedAt == nil },
        sort: \UserProfile.createdAt
    ) private var profiles: [UserProfile]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Sosyal", eyebrow: "Arkadaşlar", subtitle: "Arkadaşlarınla aynı anda çalış")
                if let social {
                    SocialContent(social: social)
                } else {
                    Text("Sosyal servis şu an kullanılamıyor.")
                        .fokusTextStyle(.callout)
                        .foregroundStyle(.fkSecondaryLabel)
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .refreshable { await social?.refresh() }
        .accessibilityIdentifier("screen.social")
        // İlk açılışta ve Apple bağı değişince (giriş/çıkış) oturumu yeniden oku.
        .task(id: profiles.first?.appleUserId) { await social?.refresh() }
        .onAppear { social?.activate() }
        .onDisappear { social?.deactivate() }
    }
}

/// `SocialStatus`'a göre içerik.
private struct SocialContent: View {
    let social: any SocialService

    var body: some View {
        let snapshot = social.snapshot
        switch snapshot.status {
        case .loading:
            Text("Yükleniyor…")
                .fokusTextStyle(.subheadline)
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityIdentifier("social.loading")
        case .signedOut:
            SocialGateView(social: social)
        case .needsUsername:
            SocialUsernameSetupView(social: social)
        case .iCloudUnavailable, .unreachable:
            SocialUnavailableView(social: social)
        case .ready:
            if let profile = snapshot.profile {
                SocialHomeView(social: social, snapshot: snapshot, profile: profile)
            }
        }
    }
}

#Preview("Giriş kapısı") {
    SocialScreen()
        .fokusTheme()
        .environment(\.socialService, PreviewSupport.socialService(signedIn: false))
        .modelContainer(PreviewSupport.onboardedContainer())
}

#Preview("Hazır") {
    SocialScreen()
        .fokusTheme()
        .environment(\.socialService, PreviewSupport.socialService(signedIn: true))
        .modelContainer(PreviewSupport.onboardedContainer())
}
