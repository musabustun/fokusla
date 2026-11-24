import FokusDomain
import Foundation

extension CloudSocialService {
    // MARK: - Davet ve istek

    public func createFriendInvite() async throws -> FriendInvite {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            let space = try await self.openFriendSpace(identity, toUsername: nil, mailId: nil)
            guard let url = space.inviteURL else { throw SocialError(.unknown) }
            self.rebuild()
            return FriendInvite(id: space.id.name, url: url, createdAt: space.info.createdAt)
        }
    }

    public func cancelInvite(id: String) async throws { try await withdraw(id) }

    public func cancelRequest(id: String) async throws { try await withdraw(id) }

    private func withdraw(_ id: String) async throws {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            guard let space = self.world(identity).pendingSpaces.first(where: { $0.id.name == id }) else {
                throw SocialError(.requestNotFound)
            }
            try await self.discard(space)
            self.rebuild()
        }
    }

    /// Posta gibi: ad birebir varsa ve istek kabul ediyorsa mektup gider; yoksa `userNotFound`.
    @discardableResult
    public func sendFriendRequest(_ lookup: FriendLookup) async throws -> FriendRequest {
        guard case let .username(raw) = lookup else { throw SocialError(.invalidInviteCode) }
        guard case let .valid(username) = SocialCalc.validateUsername(raw) else { throw SocialError(.invalidUsername) }
        return try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            try self.checkNewRequest(to: username, identity)
            guard let claim = try await self.cloud.claim(forKey: SocialDirectory.claimKey(forUsername: username)),
                  claim.acceptsRequests
            else { throw SocialError(.userNotFound) }

            let mailId = Self.newId()
            let space = try await self.openFriendSpace(identity, toUsername: username, mailId: mailId)
            do {
                guard let url = space.inviteURL else { throw SocialError(.unknown) }
                let payload = SocialMailPayload(
                    v: SocialMailPayload.currentVersion, username: identity.username, url: url)
                let sealed = try SocialMailCrypto.seal(
                    JSONEncoder().encode(payload), publicKey: claim.publicKey, mailbox: claim.mailbox)
                try await self.cloud.sendMail(id: mailId, mailbox: claim.mailbox, sealed: sealed)
            } catch {
                // Mektup gitmediyse boşta kalan davet de kalmasın; silinemezse süresi dolunca temizlenir.
                try? await self.cloud.removeSpace(space.id)
                self.spaces.removeAll { $0.id == space.id }
                throw error
            }
            self.rebuild()
            return FriendRequest(
                id: space.id.name, direction: .outgoing, user: SocialUser(userId: "", username: username),
                createdAt: space.info.createdAt)
        }
    }

    private func checkNewRequest(to username: String, _ identity: SocialIdentity) throws {
        if username == identity.username { throw SocialError(.cannotAddSelf) }
        let world = world(identity)
        if world.friendships.contains(where: { $0.peer.username == username }) { throw SocialError(.alreadyFriends) }
        if world.pendingSpaces.contains(where: { $0.info.toUsername == username })
            || world.visibleIncoming.contains(where: { $0.username == username }) {
            throw SocialError(.requestExists)
        }
    }

    private func openFriendSpace(
        _ identity: SocialIdentity, toUsername: String?, mailId: String?
    ) async throws -> SocialSpace {
        guard world(identity).pendingSpaces.count < Self.maxPendingInvites else { throw SocialError(.tooManyRequests) }
        let createdAt = now()
        guard let card = makeCard(joinedAt: createdAt, kind: .friend) else { throw SocialError(.noProfile) }
        let space = try await cloud.createSpace(
            name: "friend-\(Self.newId())",
            info: SocialSpaceInfo(
                kind: .friend, toUsername: toUsername, mailId: mailId, createdAt: createdAt),
            card: card)
        spaces.append(space)
        return space
    }

    // MARK: - Yanıt

    public func respondToRequest(id: String, accept: Bool) async throws {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            let mail = try self.incomingMail(id, identity)
            if accept {
                do {
                    _ = try await self.join(SocialInvite(url: mail.url), identity, from: mail)
                } catch let error as SocialError where error.code == .inviteInvalid {
                    // Gönderen geri çekmiş: istek listeden düşer.
                    try await self.markHandled([mail.id])
                    self.rebuild()
                    throw SocialError(.requestNotFound)
                }
            }
            try await self.markHandled([mail.id])
            await self.reload()
        }
    }

    public func blockRequest(id: String) async throws {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            let mail = try self.incomingMail(id, identity)
            try await self.markHandled([mail.id], blocking: [mail.senderId])
            self.rebuild()
        }
    }

    private func incomingMail(_ id: String, _ identity: SocialIdentity) throws -> IncomingMail {
        guard let mail = world(identity).visibleIncoming.first(where: { $0.id == id }) else {
            throw SocialError(.requestNotFound)
        }
        return mail
    }

    private func markHandled(_ ids: [String], blocking: [String] = []) async throws {
        guard var next = identity else { throw SocialError(.noProfile) }
        // Kutuda artık bulunmayan mektupların kimliği tutulmaz (liste büyümesin).
        let present = Set(incoming.map(\.id)).union(ids)
        next.handledMailIds = (next.handledMailIds + ids).filter(present.contains).uniqued()
        next.blockedIds = (next.blockedIds + blocking).uniqued()
        try await saveIdentity(next)
    }

    @discardableResult
    public func acceptInvite(_ invite: SocialInvite) async throws -> SocialInviteOutcome {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            return try await self.join(invite, identity)
        }
    }

    /// Daveti kabul eder, kartımı yazar ve yeniden yükler. `mail`: davet bir istekten geldiyse göndereniyle eşleşmeli.
    func join(
        _ invite: SocialInvite, _ identity: SocialIdentity, from mail: IncomingMail? = nil
    ) async throws -> SocialInviteOutcome {
        let space: SocialSpace
        do {
            space = try await cloud.acceptInvite(invite)
        } catch SocialCloudError.notFound, SocialCloudError.permission {
            throw SocialError(.inviteInvalid)
        }
        switch space.info.kind {
        case .friend:
            return try await joinFriend(space, identity, from: mail)
        case .room:
            guard mail == nil else {
                try await cloud.removeSpace(space.id)
                throw SocialError(.inviteInvalid)
            }
            return try await joinRoom(space, identity)
        }
    }

    private func joinFriend(
        _ space: SocialSpace, _ identity: SocialIdentity, from mail: IncomingMail?
    ) async throws -> SocialInviteOutcome {
        // Karttaki adın gerçek sahibi daveti açan kişi olmalı; istekten geldiyse isteği gönderen de o olmalı.
        guard let peer = world(identity).peer(in: space), peer.leftAt == nil, let peerId = peer.creatorId,
              peerId == space.id.ownerName, try await nameOwner(peer.username) == peerId,
              mail.map({ $0.senderId == peerId && $0.username == peer.username }) ?? true
        else {
            try await cloud.removeSpace(space.id)
            throw SocialError(.inviteInvalid)
        }
        if world(identity).friendships.contains(where: { $0.userId == peerId && $0.space.id != space.id }) {
            try await cloud.removeSpace(space.id)
            throw SocialError(.alreadyFriends)
        }
        // Daveti bilerek kabul etmek engeli kaldırır.
        if identity.blockedIds.contains(peerId) {
            var next = identity
            next.blockedIds.removeAll { $0 == peerId }
            try await saveIdentity(next)
        }
        guard let card = makeCard(joinedAt: now(), kind: .friend) else { throw SocialError(.noProfile) }
        try await cloud.saveCards([space.id: card])
        await reload()
        return .friend(username: peer.username)
    }

    // MARK: - Arkadaşlıktan çıkarma ve engelleme

    public func removeFriend(userId: String) async throws {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            try await self.discard(self.friendship(userId, identity).space)
            self.rebuild()
        }
    }

    public func blockFriend(userId: String) async throws {
        try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            let friendship = try self.friendship(userId, identity)
            try await self.markHandled([], blocking: [friendship.userId])
            try await self.discard(friendship.space)
            self.rebuild()
        }
    }

    private func friendship(_ userId: String, _ identity: SocialIdentity) throws -> SocialWorld.Friendship {
        guard let match = world(identity).friendships.first(where: { $0.userId == userId }) else {
            throw SocialError(.friendNotFound)
        }
        return match
    }

    // MARK: - Gelen mektuplar

    /// Mektupları açar; bozuk olanlar ve göndereni iddia ettiği adın sahibi olmayanlar yok sayılır. Kişi başına
    /// yalnız en yeni mektup sayılır.
    func loadIncoming(_ identity: SocialIdentity) async throws -> [IncomingMail] {
        let known = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var senders = Set<String>()
        var result: [IncomingMail] = []
        let mails = try await cloud.mail(in: identity.mailbox).sorted { $0.createdAt > $1.createdAt }
        for mail in mails where !rejectedMailIds.contains(mail.id) && !identity.blockedIds.contains(mail.senderId) {
            let opened: IncomingMail?
            if let cached = known[mail.id] { opened = cached } else { opened = try await open(mail, identity) }
            guard let opened else {
                rejectedMailIds.insert(mail.id)
                continue
            }
            if senders.insert(mail.senderId).inserted { result.append(opened) }
        }
        return result
    }

    private func open(_ mail: SocialMail, _ identity: SocialIdentity) async throws -> IncomingMail? {
        guard let data = try? SocialMailCrypto.open(mail.sealed, privateKey: identity.privateKey, mailbox: identity.mailbox),
              let payload = try? JSONDecoder().decode(SocialMailPayload.self, from: data),
              payload.v == SocialMailPayload.currentVersion,
              case let .valid(username) = SocialCalc.validateUsername(payload.username),
              SocialInvite.isShareURL(payload.url), try await nameOwner(username) == mail.senderId
        else { return nil }
        return IncomingMail(
            id: mail.id, senderId: mail.senderId, username: username, url: payload.url, createdAt: mail.createdAt)
    }
}
