import FokusDomain
import Foundation

// MockSocialService'in durum yönetimi, davet kodu üretimi ve simüle yanıt zamanlayıcıları.

extension MockSocialService {
    private static let inviteCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let maxInviteCodeAttempts = 50

    static func requestTimerKey(_ requestId: String) -> String { "request:\(requestId)" }
    static func roomTimerKey(_ roomId: String) -> String { "room:\(roomId)" }

    // MARK: - Durum yönetimi

    func load(_ userId: String?) {
        cancelAllResponseTimers()
        currentUserId = userId
        account = userId.flatMap { MockSocialStore.readAccount(storage: storage, appleUserId: $0) }
        status = userId == nil ? .signedOut : (account == nil ? .needsUsername : .ready)
        commit()
        // Yeniden yüklemeden önce bekleyen giden istekler yine kabul edilsin.
        for request in account?.requests ?? [] where request.direction == .outgoing {
            scheduleAcceptance(requestId: request.id)
        }
        // Kendi odama henüz kimse katılmadıysa simüle edilen katılım da yeniden planlansın.
        if case let .hosted(id, _, _, _, guests)? = account?.room, guests.isEmpty {
            scheduleGuestJoin(roomId: id)
        }
    }

    /// Oturum başka bir kullanıcıya geçtiyse (ya da çıkıldıysa) hesabı yeniden yükler.
    func syncSession(_ userId: String?) {
        if userId != currentUserId || (userId == nil && status != .signedOut) { load(userId) }
    }

    func requireSession() async throws -> String {
        let userId = await sessionProvider() ?? MockSocialStore.readPreviewAccountId(storage: storage)
        syncSession(userId)
        guard let userId else { throw SocialError(.notSignedIn) }
        return userId
    }

    func requireProfile() async throws -> StoredAccount {
        _ = try await requireSession()
        return try requireAccount()
    }

    func requireAccount() throws -> StoredAccount {
        guard let account else { throw SocialError(.noProfile) }
        return account
    }

    func requireRoom() throws -> SocialRoom {
        guard let room = snapshot.room else { throw SocialError(.roomNotFound) }
        return room
    }

    /// Hesabı değiştirir, saklar ve (`emit` ise) yeni anlık görüntü yayınlar.
    func updateAccount(_ next: StoredAccount, emit: Bool = true) {
        guard let currentUserId else { return }
        account = next
        MockSocialStore.writeAccount(storage: storage, appleUserId: currentUserId, account: next)
        if emit { commit() }
    }

    func commit() {
        let next = MockSocialSnapshot.build(
            MockSocialSnapshotInput(
                status: status, account: account, presences: presences, worldStartedAt: worldStartedAt,
                now: now()))
        if next != snapshot { setSnapshot(next) }
    }

    func seedAccount(username: String) -> StoredAccount {
        let current = now()
        func seedUsers(_ names: [String]) -> [SimulatedUser] { names.compactMap { SimulatedUsers.find(username: $0) } }
        let friends = seedUsers(SimulatedUsers.seedFriendUsernames).map {
            StoredFriend(userId: $0.userId, username: $0.username, friendsSince: current)
        }
        let requests = seedUsers(SimulatedUsers.seedIncomingRequestUsernames).map {
            FriendRequest(
                id: Identifiers.lowercasedString(Identifiers.newId()), direction: .incoming, user: $0.user,
                createdAt: current)
        }
        let profile = SocialProfile(
            userId: "mock-self-" + Identifiers.lowercasedString(Identifiers.newId()), username: username,
            inviteCode: generateInviteCode(), isDiscoverable: true)
        return StoredAccount(profile: profile, friends: friends, requests: requests)
    }

    func generateInviteCode() -> String {
        var used = Set(SimulatedUsers.users.map(\.inviteCode))
        used.formUnion(SimulatedUsers.rooms.map(\.inviteCode))
        if let account {
            used.insert(account.profile.inviteCode)
            if case let .hosted(_, _, inviteCode, _, _)? = account.room { used.insert(inviteCode) }
        }
        let alphabet = Self.inviteCodeAlphabet
        func pick() -> Character {
            let index = Int((random() * Double(alphabet.count)).rounded(.down))
            return alphabet[min(max(index, 0), alphabet.count - 1)]
        }
        var code = ""
        for _ in 0..<Self.maxInviteCodeAttempts {
            code = String((0..<SocialCalc.inviteCodeLength).map { _ in pick() })
            if !used.contains(code) { return code }
        }
        return code
    }

    // MARK: - Simüle yanıtlar

    private func schedule(_ key: String, _ action: @escaping @MainActor (MockSocialService) -> Void) {
        if responseDelayMs <= 0 {
            action(self)
            return
        }
        clearResponseTimer(key)
        responseTimers[key] = scheduler.after(milliseconds: responseDelayMs) { [weak self] in
            guard let self else { return }
            self.responseTimers[key] = nil
            action(self)
        }
    }

    func clearResponseTimer(_ key: String) {
        responseTimers.removeValue(forKey: key)?.cancel()
    }

    func cancelAllResponseTimers() {
        let timers = responseTimers.values
        responseTimers = [:]
        for timer in timers { timer.cancel() }
    }

    func clearRoomTimer(_ room: StoredRoom?) {
        if case let .hosted(id, _, _, _, _)? = room { clearResponseTimer(Self.roomTimerKey(id)) }
    }

    func scheduleAcceptance(requestId: String) {
        schedule(Self.requestTimerKey(requestId)) { service in
            guard let account = service.account,
                let request = account.requests.first(where: { $0.id == requestId && $0.direction == .outgoing })
            else { return }
            service.updateAccount(service.resolveRequest(account, request, accept: true))
        }
    }

    func scheduleGuestJoin(roomId: String) {
        schedule(Self.roomTimerKey(roomId)) { service in
            guard let account = service.account,
                case let .hosted(id, name, inviteCode, createdAt, guests)? = account.room, id == roomId
            else { return }
            let current = service.now()
            let guestIds = Set(guests.map(\.userId))
            let guest = MockSocialSnapshot.sortFriends(account.friends).first {
                !guestIds.contains($0.userId) && SimulatedUsers.find(userId: $0.userId) != nil
                    && SocialCalc.effectivePresenceState(service.presences[$0.userId], now: current) != .offline
            }
            guard let guest else { return }
            var next = account
            next.room = .hosted(
                id: id, name: name, inviteCode: inviteCode, createdAt: createdAt,
                guests: guests + [StoredRoomGuest(userId: guest.userId, joinedAt: current)])
            service.updateAccount(next)
        }
    }
}
