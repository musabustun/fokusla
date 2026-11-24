import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Hazır sosyal ekranı. Dar alan (iPhone, iPad dikey): tek sütun (oda üstte). Geniş alan (iPad yatay):
/// solda istekler, arkadaşlar ve profil; sağda oda ve kendi durumum (yan yana).
struct SocialHomeView: View {
    let social: any SocialService
    let snapshot: SocialSnapshot
    let profile: SocialProfile

    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }) private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil }) private var segments: [FocusSegment]

    @State private var addFriend = false
    @State private var availableWidth: CGFloat = 0

    /// İki sütun ancak her sütuna rahat sığacak kadar genişlikte (iPad kenar çubuğu açıkken dikeyde
    /// detay alanı dardır → tek sütun; yatayda iki sütun).
    private static let twoColumnMinWidth: CGFloat = 760

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let own = SocialOwnPresence.make(sessions: sessions, segments: segments, now: now)
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                if snapshot.isOffline {
                    Text("Bağlantı yok; son bilinen durum gösteriliyor.")
                        .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                        .accessibilityIdentifier("social.offline")
                }
                if availableWidth >= Self.twoColumnMinWidth {
                    HStack(alignment: .top, spacing: FokusSpacing.xxl) {
                        VStack(alignment: .leading, spacing: FokusSpacing.xxl) { primary(now: now) }
                        VStack(alignment: .leading, spacing: FokusSpacing.xxl) { room(own: own, now: now) }
                    }
                } else {
                    VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                        room(own: own, now: now)
                        primary(now: now)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .sheet(isPresented: $addFriend) { SocialAddFriendSheet(social: social) }
        .socialContainer("social.home")
    }

    @ViewBuilder private func primary(now: Date) -> some View {
        SocialRequestsSection(social: social, requests: snapshot.requests, invites: snapshot.pendingInvites)
        SocialFriendsSection(social: social, friends: snapshot.friends, now: now) { addFriend = true }
        SocialProfileSection(social: social, profile: profile)
    }

    @ViewBuilder private func room(own: SocialPresence, now: Date) -> some View {
        SocialRoomPanel(social: social, room: snapshot.room, friendRooms: snapshot.friendRooms, own: own, now: now)
        SocialOwnStatusSection(presence: own, now: now, isDiscoverable: profile.isDiscoverable)
    }
}
