import FokusDomain
import Foundation

extension CloudSocialService {
    @discardableResult
    public func createRoom(name: String) async throws -> SocialRoom {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= socialRoomNameMaxLength else { throw SocialError(.invalidRoomName) }
        guard SocialContentFilter.isAcceptable(trimmed) else { throw SocialError(.inappropriateText) }
        return try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            try await self.leaveCurrentRoom(identity)
            let createdAt = self.now()
            guard let card = self.makeCard(joinedAt: createdAt, kind: .room) else { throw SocialError(.noProfile) }
            let space = try await self.cloud.createSpace(
                name: "room-\(Self.newId())",
                info: SocialSpaceInfo(kind: .room, name: trimmed, createdAt: createdAt),
                card: card)
            self.spaces.append(space)
            await self.announceRoomChange()
            return try self.requireRoom()
        }
    }

    @discardableResult
    public func joinRoom(_ target: RoomTarget) async throws -> SocialRoom {
        guard case let .room(id) = target else { throw SocialError(.invalidInviteCode) }
        return try await exclusiveThrowing {
            let identity = try await self.requireIdentity()
            guard let url = self.world(identity).friendRoomURL(id: id) else { throw SocialError(.roomNotFound) }
            do {
                _ = try await self.join(SocialInvite(url: url), identity)
            } catch let error as SocialError where error.code == .inviteInvalid {
                throw SocialError(.roomNotFound)
            }
            return try self.requireRoom()
        }
    }

    public func leaveRoom() async {
        do {
            try await exclusiveThrowing {
                let identity = try await self.requireIdentity()
                try await self.leaveCurrentRoom(identity)
                await self.announceRoomChange()
            }
        } catch {
            // Sözleşme hata atmaz; oda listede kalır ve kullanıcı yeniden deneyebilir.
            logger.error("Odadan çıkılamadı: \(String(describing: error), privacy: .public)")
        }
    }

    func joinRoom(_ space: SocialSpace, _ identity: SocialIdentity) async throws -> SocialInviteOutcome {
        let mine = world(identity).myCard(in: space)
        if mine == nil || mine?.leftAt != nil {
            if space.activeCards().count >= Self.maxRoomMembers {
                try await cloud.removeSpace(space.id)
                throw SocialError(.roomFull)
            }
            try await leaveCurrentRoom(identity)
            guard let card = makeCard(joinedAt: now(), kind: .room) else { throw SocialError(.noProfile) }
            try await cloud.saveCards([space.id: card])
        }
        await reload()
        await announceRoomChange()
        return .room(name: space.info.name)
    }

    private func leaveCurrentRoom(_ identity: SocialIdentity) async throws {
        guard let room = world(identity).currentRoom else { return }
        try await discard(room)
    }

    /// Arkadaş kartlarındaki oda duyurusunu günceller. Başarısızsa bir sonraki kalp atışı düzeltir.
    private func announceRoomChange() async {
        rebuild()
        do {
            try await publishCards(force: true)
        } catch {
            logger.error("Oda duyurulamadı: \(String(describing: error), privacy: .public)")
        }
    }

    private func requireRoom() throws -> SocialRoom {
        guard let room = snapshot.room else { throw SocialError(.roomNotFound) }
        return room
    }
}
