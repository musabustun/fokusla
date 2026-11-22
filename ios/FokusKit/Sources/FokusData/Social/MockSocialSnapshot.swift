import FokusDomain
import Foundation

// Saklanan hesap + simüle dünya durumundan `SocialSnapshot` üreten saf fonksiyonlar
// (web `mockSocialSnapshot.ts`). Her çağrı YENİ değerler döner; girdiler değiştirilmez.

public struct MockSocialSnapshotInput: Sendable {
    public var status: SocialStatus
    public var account: StoredAccount?
    /// Simüle kullanıcıların canlı durumları (anahtar: userId).
    public var presences: [String: SocialPresence]
    /// Simüle odaların oluşturulma/katılma zamanlarının referans anı.
    public var worldStartedAt: Date
    public var now: Date

    public init(
        status: SocialStatus, account: StoredAccount?, presences: [String: SocialPresence],
        worldStartedAt: Date, now: Date
    ) {
        self.status = status
        self.account = account
        self.presences = presences
        self.worldStartedAt = worldStartedAt
        self.now = now
    }
}

public enum MockSocialSnapshot {
    private static let turkish = Locale(identifier: "tr")

    /// Arkadaşlar kullanıcı adına göre (Türkçe sıralama).
    public static func sortFriends(_ friends: [StoredFriend]) -> [StoredFriend] {
        friends.enumerated().sorted { lhs, rhs in
            let order = lhs.element.username.compare(rhs.element.username, locale: turkish)
            return order == .orderedSame ? lhs.offset < rhs.offset : order == .orderedAscending
        }.map(\.element)
    }

    /// Ev sahibi önce, sonra katılma zamanına göre.
    private static func sortMembers(_ members: [RoomMember]) -> [RoomMember] {
        members.enumerated().sorted { lhs, rhs in
            if lhs.element.isHost != rhs.element.isHost { return lhs.element.isHost }
            if lhs.element.joinedAt != rhs.element.joinedAt { return lhs.element.joinedAt < rhs.element.joinedAt }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private static func simulatedMember(
        userId: String, hostUserId: String, joinedAt: Date, presences: [String: SocialPresence]
    ) -> RoomMember? {
        guard let simulated = SimulatedUsers.find(userId: userId) else { return nil }
        return RoomMember(
            userId: userId, username: simulated.username, isSelf: false, isHost: userId == hostUserId,
            presence: presences[userId], joinedAt: joinedAt)
    }

    private static func simulatedRoomMembers(
        _ room: SimulatedRoom, presences: [String: SocialPresence], worldStartedAt: Date
    ) -> [RoomMember] {
        room.members.compactMap {
            simulatedMember(
                userId: $0.userId, hostUserId: room.hostUserId,
                joinedAt: SimulatedUsers.minutesBefore(worldStartedAt, $0.joinedMinutesAgo),
                presences: presences)
        }
    }

    private static func buildRoom(
        _ account: StoredAccount, presences: [String: SocialPresence], worldStartedAt: Date
    ) -> SocialRoom? {
        guard let stored = account.room else { return nil }
        let profile = account.profile
        func selfMember(isHost: Bool, joinedAt: Date) -> RoomMember {
            RoomMember(
                userId: profile.userId, username: profile.username, isSelf: true, isHost: isHost,
                presence: account.selfPresence, joinedAt: joinedAt)
        }

        switch stored {
        case let .hosted(id, name, inviteCode, createdAt, guests):
            let guestMembers = guests.compactMap {
                simulatedMember(
                    userId: $0.userId, hostUserId: profile.userId, joinedAt: $0.joinedAt, presences: presences)
            }
            return SocialRoom(
                id: id, name: name, hostUserId: profile.userId, inviteCode: inviteCode,
                members: sortMembers([selfMember(isHost: true, joinedAt: createdAt)] + guestMembers),
                createdAt: createdAt)
        case let .joined(roomId, joinedAt):
            guard let simulated = SimulatedUsers.rooms.first(where: { $0.id == roomId }) else { return nil }
            let others = simulatedRoomMembers(simulated, presences: presences, worldStartedAt: worldStartedAt)
            return SocialRoom(
                id: simulated.id, name: simulated.name, hostUserId: simulated.hostUserId,
                inviteCode: simulated.inviteCode,
                members: sortMembers(others + [selfMember(isHost: false, joinedAt: joinedAt)]),
                createdAt: SimulatedUsers.minutesBefore(worldStartedAt, simulated.createdMinutesAgo))
        }
    }

    private static func buildFriendRooms(
        _ account: StoredAccount, currentRoomId: String?, presences: [String: SocialPresence], now: Date
    ) -> [RoomSummary] {
        let friendIds = Set(account.friends.map(\.userId))
        return SimulatedUsers.rooms
            .filter { friendIds.contains($0.hostUserId) && $0.id != currentRoomId }
            .compactMap { room -> RoomSummary? in
                guard let host = SimulatedUsers.find(userId: room.hostUserId) else { return nil }
                let focusingCount = room.members.filter {
                    SocialCalc.effectivePresenceState(presences[$0.userId], now: now) == .focusing
                }.count
                return RoomSummary(
                    id: room.id, name: room.name, host: host.user, memberCount: room.members.count,
                    focusingCount: focusingCount)
            }
    }

    public static func build(_ input: MockSocialSnapshotInput) -> SocialSnapshot {
        guard input.status == .ready, let account = input.account else { return .empty(input.status) }
        let presences = input.presences
        let friends = sortFriends(account.friends).map {
            SocialFriend(
                userId: $0.userId, username: $0.username, presence: presences[$0.userId],
                friendsSince: $0.friendsSince)
        }
        let requests = account.requests.enumerated()
            .sorted { lhs, rhs in
                lhs.element.createdAt == rhs.element.createdAt
                    ? lhs.offset < rhs.offset : lhs.element.createdAt > rhs.element.createdAt
            }.map(\.element)
        let room = buildRoom(account, presences: presences, worldStartedAt: input.worldStartedAt)
        return SocialSnapshot(
            status: input.status, profile: account.profile, friends: friends, requests: requests,
            room: room,
            friendRooms: buildFriendRooms(
                account, currentRoomId: room?.id, presences: presences, now: input.now))
    }
}
