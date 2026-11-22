import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Hazır sosyal ekranı. iPhone: tek sütun (oda üstte). iPad (regular): solda istekler, arkadaşlar ve
/// profil; sağda oda ve kendi durumum (yan yana).
struct SocialHomeView: View {
    let social: any SocialService
    let snapshot: SocialSnapshot
    let profile: SocialProfile

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }) private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil }) private var segments: [FocusSegment]

    @State private var addFriend = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let own = SocialOwnPresence.make(sessions: sessions, segments: segments, now: now)
            Group {
                if horizontalSizeClass == .regular {
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
        .sheet(isPresented: $addFriend) { SocialAddFriendSheet(social: social) }
        .socialContainer("social.home")
    }

    @ViewBuilder private func primary(now: Date) -> some View {
        SocialRequestsSection(social: social, requests: snapshot.requests)
        SocialFriendsSection(social: social, friends: snapshot.friends, now: now) { addFriend = true }
        SocialProfileSection(social: social, profile: profile)
    }

    @ViewBuilder private func room(own: SocialPresence, now: Date) -> some View {
        SocialRoomPanel(social: social, room: snapshot.room, friendRooms: snapshot.friendRooms, own: own, now: now)
        SocialOwnStatusSection(presence: own, now: now, isDiscoverable: profile.isDiscoverable)
    }
}
