import FokusDomain
import Foundation

/// Açılmış ve göndereni doğrulanmış gelen mektup.
struct IncomingMail: Sendable, Hashable {
    let id: String
    let senderId: String
    let username: String
    let personId: String
    let url: URL
    let createdAt: Date
}

/// Mektubun şifreli içeriği.
struct SocialMailPayload: Codable, Sendable {
    static let currentVersion = 1

    var v: Int
    var username: String
    var personId: String
    var url: URL
}

/// Yüklenmiş sosyal durumun saf görünümü: alanlardan arkadaşlar, bekleyenler ve oda türetilir. Yan etkisizdir.
struct SocialWorld {
    static let inviteLifetime: TimeInterval = 30 * 24 * 3600
    /// Arkadaşın duyurduğu oda bu süre boyunca yenilenmediyse listelenmez.
    static let friendRoomLifetime: TimeInterval = 12 * 3600

    let identity: SocialIdentity
    let spaces: [SocialSpace]
    let incoming: [IncomingMail]
    let now: Date
    let calendar: Calendar

    struct Friendship {
        let space: SocialSpace
        let mine: SocialCard
        let peer: SocialCard
    }

    private func isBlocked(_ card: SocialCard) -> Bool {
        identity.blockedIds.contains(card.personId)
            || card.creatorId.map(identity.blockedIds.contains) == true
    }

    private func peer(in space: SocialSpace) -> SocialCard? {
        space.cards.first { $0.personId != identity.personId }
    }

    private var friendSpaces: [SocialSpace] { spaces.filter { $0.info.kind == .friend } }

    /// Aynı kişiyle birden çok alan varsa adı en küçük olan geçerlidir (iki taraf da aynı alanı seçer).
    var friendships: [Friendship] {
        var byPeer: [String: Friendship] = [:]
        for friendship in allFriendships {
            let key = friendship.peer.personId
            if let current = byPeer[key], current.space.id.name <= friendship.space.id.name { continue }
            byPeer[key] = friendship
        }
        return Array(byPeer.values)
    }

    private var allFriendships: [Friendship] {
        friendSpaces.compactMap { space in
            guard let mine = space.card(of: identity.personId), mine.leftAt == nil,
                  let peer = peer(in: space), peer.leftAt == nil, !isBlocked(peer)
            else { return nil }
            return Friendship(space: space, mine: mine, peer: peer)
        }
    }

    /// Benim açtığım, henüz kabul edilmemiş davetler.
    var pendingSpaces: [SocialSpace] {
        friendSpaces.filter { $0.id.isMine && peer(in: $0) == nil && !isExpired($0) }
    }

    private func isExpired(_ space: SocialSpace) -> Bool {
        now.timeIntervalSince(space.info.createdAt) > Self.inviteLifetime
    }

    /// Silinmesi/ayrılınması gereken alanlar: karşı tarafın ayrıldığı, yarım kalan ayrılma, süresi dolan davet,
    /// engellenen kişi ve çift davetin fazlası.
    var obsoleteSpaces: [SocialSpace] {
        let canonical = Set(friendships.map(\.space.id))
        return spaces.filter { space in
            let mine = space.card(of: identity.personId)
            if mine?.leftAt != nil { return true }
            guard space.info.kind == .friend else { return false }
            guard let peer = peer(in: space) else { return space.id.isMine && isExpired(space) }
            if peer.leftAt != nil || isBlocked(peer) { return true }
            // Fazla alanı yalnız sahibi siler; aksi halde iki taraf birbirinin alanını silebilirdi.
            return mine != nil && space.id.isMine && !canonical.contains(space.id)
        }
    }

    /// Paylaşım kabul edilmiş ama kartım yazılamamış alanlar (ör. arada ağ kesildi).
    var spacesMissingMyCard: [SocialSpace] {
        friendSpaces.filter { space in
            guard !space.id.isMine, space.card(of: identity.personId) == nil, let peer = peer(in: space) else { return false }
            return peer.leftAt == nil && !isBlocked(peer)
        }
    }

    /// Kabul edilmiş davetin artık gereksiz mektubu.
    var spacesWithDeliveredMail: [SocialSpace] {
        friendSpaces.filter { $0.id.isMine && $0.info.mailId != nil && peer(in: $0) != nil }
    }

    var currentRoom: SocialSpace? {
        spaces.filter { $0.info.kind == .room }
            .compactMap { space -> (SocialSpace, Date)? in
                guard let mine = space.card(of: identity.personId), mine.leftAt == nil else { return nil }
                return (space, mine.joinedAt)
            }
            .max { $0.1 < $1.1 }?.0
    }

    var visibleIncoming: [IncomingMail] {
        let friends = Set(friendships.map(\.peer.personId))
        return incoming.filter {
            !identity.handledMailIds.contains($0.id) && !identity.blockedIds.contains($0.senderId)
                && !identity.blockedIds.contains($0.personId) && !friends.contains($0.personId)
        }
    }

    func shownPresence(_ card: SocialCard) -> SocialPresence? {
        card.presence.map { SocialCalc.presenceForToday($0, now: now, calendar: calendar) }
    }

    /// Odamı (ev sahibiysem) arkadaşlarıma duyuran bilgi.
    func roomAnnouncement(ownPresence: SocialPresence?) -> SocialCardRoom? {
        guard let room = currentRoom, room.info.hostPersonId == identity.personId, let url = room.inviteURL else { return nil }
        let members = room.activeCards()
        let focusing = members.filter { card in
            let presence = card.personId == identity.personId ? ownPresence : shownPresence(card)
            return SocialCalc.effectivePresenceState(presence, now: now) == .focusing
        }
        return SocialCardRoom(
            id: room.id.name, name: room.info.name, url: url, memberCount: members.count,
            focusingCount: focusing.count)
    }

    // MARK: - Anlık görüntü

    func snapshot(isOffline: Bool) -> SocialSnapshot {
        SocialSnapshot(
            status: .ready,
            profile: SocialProfile(
                userId: identity.personId, username: identity.username, inviteCode: "",
                isDiscoverable: identity.isDiscoverable),
            friends: friends, requests: requests, room: room, friendRooms: friendRooms,
            pendingInvites: pendingInvites, isOffline: isOffline)
    }

    private var friends: [SocialFriend] {
        friendships
            .map {
                SocialFriend(
                    userId: $0.peer.personId, username: $0.peer.username, presence: shownPresence($0.peer),
                    friendsSince: max($0.mine.joinedAt, $0.peer.joinedAt))
            }
            .sorted { $0.username.compare($1.username, locale: Locale(identifier: "tr_TR")) == .orderedAscending }
    }

    private var requests: [FriendRequest] {
        let received = visibleIncoming.map {
            FriendRequest(
                id: $0.id, direction: .incoming, user: SocialUser(userId: $0.personId, username: $0.username),
                createdAt: $0.createdAt)
        }
        let sent = pendingSpaces.compactMap { space -> FriendRequest? in
            guard let username = space.info.toUsername else { return nil }
            return FriendRequest(
                id: space.id.name, direction: .outgoing, user: SocialUser(userId: "", username: username),
                createdAt: space.info.createdAt)
        }
        return (received + sent).sorted { $0.createdAt > $1.createdAt }
    }

    private var pendingInvites: [FriendInvite] {
        pendingSpaces
            .compactMap { space -> FriendInvite? in
                guard space.info.toUsername == nil, let url = space.inviteURL else { return nil }
                return FriendInvite(id: space.id.name, url: url, createdAt: space.info.createdAt)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var room: SocialRoom? {
        guard let space = currentRoom else { return nil }
        let host = space.info.hostPersonId
        let members = space.activeCards()
            .map { card in
                RoomMember(
                    userId: card.personId, username: card.username, isSelf: card.personId == identity.personId,
                    isHost: card.personId == host, presence: shownPresence(card), joinedAt: card.joinedAt)
            }
            .sorted { ($0.isHost ? 0 : 1, $0.joinedAt, $0.userId) < ($1.isHost ? 0 : 1, $1.joinedAt, $1.userId) }
        return SocialRoom(
            id: space.id.name, name: space.info.name, hostUserId: host, inviteCode: "", members: members,
            createdAt: space.info.createdAt, inviteURL: space.inviteURL)
    }

    private var friendRooms: [RoomSummary] {
        let currentId = currentRoom?.id.name
        return friendships
            .compactMap { friendship -> RoomSummary? in
                guard let room = friendship.peer.room, room.id != currentId,
                      let updatedAt = friendship.peer.presence?.updatedAt,
                      now.timeIntervalSince(updatedAt) <= Self.friendRoomLifetime
                else { return nil }
                return RoomSummary(
                    id: room.id, name: room.name,
                    host: SocialUser(userId: friendship.peer.personId, username: friendship.peer.username),
                    memberCount: room.memberCount, focusingCount: room.focusingCount)
            }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "tr_TR")) == .orderedAscending }
    }

    func friendRoomURL(id: String) -> URL? {
        friendships.compactMap(\.peer.room).first { $0.id == id }?.url
    }
}
