import FokusDomain
import Foundation
import Observation

/// Sahte sosyal servis (web `MockSocialService.ts`). HİÇBİR AĞ G/Ç'si YAPMAZ.
///
///  - Profil, arkadaşlar, istekler, oda ve son yayınlanan kendi durumum `SocialStorage`'da, Apple
///    kullanıcı kimliği başına saklanır.
///  - Arkadaşlar ve odalardaki diğer kişiler `SimulatedUsers`'ın sabit dünyasından gelir; canlı
///    durumları saklanmaz, `now`'dan üretilir ve `activate()` varken zamanlayıcıyla ilerletilir.
///  - Simüle kullanıcılar arkadaşlık isteğini `responseDelayMs` sonra kabul eder; açtığım odaya
///    çevrimiçi ilk arkadaş `responseDelayMs` sonra katılır (≤ 0 → hemen).
@MainActor
@Observable
public final class MockSocialService: SocialService {
    public static let previewAccountId = "preview-device"

    public private(set) var snapshot: SocialSnapshot = .empty(.loading)

    /// Aynı modülün uzantı dosyası için (`private(set)` dosya dışından yazılamaz).
    func setSnapshot(_ next: SocialSnapshot) { snapshot = next }

    @ObservationIgnored let sessionProvider: @MainActor () async -> String?
    @ObservationIgnored let storage: any SocialStorage
    @ObservationIgnored let scheduler: any SocialScheduler
    @ObservationIgnored let now: @MainActor () -> Date
    @ObservationIgnored let random: @MainActor () -> Double
    @ObservationIgnored let delayMs: Int
    @ObservationIgnored let tickMs: Int
    @ObservationIgnored let responseDelayMs: Int
    @ObservationIgnored let worldStartedAt: Date

    @ObservationIgnored var presences: [String: SocialPresence]
    @ObservationIgnored var status: SocialStatus = .loading
    @ObservationIgnored var currentUserId: String?
    @ObservationIgnored var account: StoredAccount?
    @ObservationIgnored private var activationCount = 0
    @ObservationIgnored private var simulationTimer: SocialCancellable?
    @ObservationIgnored var responseTimers: [String: SocialCancellable] = [:]

    /// - Parameters:
    ///   - sessionProvider: Apple kullanıcı kimliği (giriş yoksa nil). Her işlemde sorulur.
    ///   - delayMs: Her async çağrının yapay gecikmesi. 0 → hiç beklemez.
    ///   - tickMs: Simülasyon adımı. ≤ 0 → zamanlayıcı hiç kurulmaz.
    ///   - responseDelayMs: Simüle arkadaşın isteği kabul etmesi / odama katılması için gecikme. ≤ 0 → hemen.
    public init(
        sessionProvider: @escaping @MainActor () async -> String?,
        storage: any SocialStorage,
        scheduler: any SocialScheduler = TaskSocialScheduler(),
        now: @escaping @MainActor () -> Date = { Date() },
        random: @escaping @MainActor () -> Double = { Double.random(in: 0..<1) },
        delayMs: Int = 250,
        tickMs: Int = 4000,
        responseDelayMs: Int = 1500
    ) {
        self.sessionProvider = sessionProvider
        self.storage = storage
        self.scheduler = scheduler
        self.now = now
        self.random = random
        self.delayMs = delayMs
        self.tickMs = tickMs
        self.responseDelayMs = responseDelayMs
        let start = now()
        self.worldStartedAt = start
        self.presences = Dictionary(
            uniqueKeysWithValues: SimulatedUsers.users.map {
                ($0.userId, SimulatedUsers.initialPresence($0, now: start))
            })
    }

    // MARK: - Abonelik (referans sayımlı)

    public func activate() {
        activationCount += 1
        if activationCount == 1 { startSimulation() }
    }

    public func deactivate() {
        guard activationCount > 0 else { return }
        activationCount -= 1
        if activationCount == 0 { stopSimulation() }
    }

    /// Tüm zamanlayıcıları durdurur (testler / servis kapatılırken).
    public func dispose() {
        activationCount = 0
        stopSimulation()
        cancelAllResponseTimers()
    }

    // MARK: - Oturum ve profil

    public func refresh() async {
        await pause()
        load(await effectiveSession())
    }

    public func startPreviewSession() async {
        MockSocialStore.writePreviewAccountId(storage: storage, Self.previewAccountId)
        await refresh()
    }

    public func checkUsername(_ raw: String) async -> UsernameCheck {
        await pause()
        switch SocialCalc.validateUsername(raw) {
        case let .invalid(problem): return .invalid(problem)
        case let .valid(username): return isUsernameTaken(username) ? .taken : .ok(username)
        }
    }

    @discardableResult
    public func claimUsername(_ raw: String) async throws -> SocialProfile {
        await pause()
        let userId = try await requireSession()
        guard case let .valid(username) = SocialCalc.validateUsername(raw) else {
            throw SocialError(.invalidUsername)
        }
        if isUsernameTaken(username) { throw SocialError(.usernameTaken) }

        if let current = account {
            if current.profile.username != username {
                var next = current
                next.profile.username = username
                updateAccount(next)
            }
        } else {
            let seeded = seedAccount(username: username)
            account = seeded
            status = .ready
            MockSocialStore.writeAccount(storage: storage, appleUserId: userId, account: seeded)
            commit()
        }
        return try requireAccount().profile
    }

    public func setDiscoverable(_ isDiscoverable: Bool) async throws {
        await pause()
        var next = try await requireProfile()
        next.profile.isDiscoverable = isDiscoverable
        if !isDiscoverable { next.selfPresence = nil }
        updateAccount(next)
    }

    public func publishPresence(_ presence: SocialPresence) async throws {
        await pause()
        var next = try await requireProfile()
        next.selfPresence = next.profile.isDiscoverable ? presence : nil
        // Odada değilsem anlık görüntü değişmez: yalnızca sakla, yayın yapma.
        updateAccount(next, emit: next.room != nil)
    }

    // MARK: - Arkadaşlık

    @discardableResult
    public func sendFriendRequest(_ lookup: FriendLookup) async throws -> FriendRequest {
        await pause()
        let current = try await requireProfile()
        let target = try resolveFriendLookup(lookup, profile: current.profile)
        if current.friends.contains(where: { $0.userId == target.userId }) {
            throw SocialError(.alreadyFriends)
        }
        if current.requests.contains(where: { $0.user.userId == target.userId }) {
            throw SocialError(.requestExists)
        }
        let request = FriendRequest(
            id: Identifiers.lowercasedString(Identifiers.newId()), direction: .outgoing, user: target.user,
            createdAt: now())
        var next = current
        next.requests = [request] + current.requests
        updateAccount(next)
        scheduleAcceptance(requestId: request.id)
        return request
    }

    public func respondToRequest(id: String, accept: Bool) async throws {
        await pause()
        let current = try await requireProfile()
        guard let request = current.requests.first(where: { $0.id == id && $0.direction == .incoming })
        else { throw SocialError(.requestNotFound) }
        updateAccount(resolveRequest(current, request, accept: accept))
    }

    public func cancelRequest(id: String) async throws {
        await pause()
        let current = try await requireProfile()
        guard let request = current.requests.first(where: { $0.id == id && $0.direction == .outgoing })
        else { throw SocialError(.requestNotFound) }
        clearResponseTimer(Self.requestTimerKey(id))
        updateAccount(resolveRequest(current, request, accept: false))
    }

    public func removeFriend(userId: String) async throws {
        await pause()
        var next = try await requireProfile()
        guard next.friends.contains(where: { $0.userId == userId }) else {
            throw SocialError(.friendNotFound)
        }
        next.friends.removeAll { $0.userId == userId }
        updateAccount(next)
    }

    // MARK: - Odalar

    @discardableResult
    public func createRoom(name: String) async throws -> SocialRoom {
        await pause()
        let current = try await requireProfile()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= socialRoomNameMaxLength else {
            throw SocialError(.invalidRoomName)
        }
        clearRoomTimer(current.room)
        let roomId = Identifiers.lowercasedString(Identifiers.newId())
        var next = current
        next.room = .hosted(
            id: roomId, name: trimmed, inviteCode: generateInviteCode(), createdAt: now(), guests: [])
        updateAccount(next)
        scheduleGuestJoin(roomId: roomId)
        return try requireRoom()
    }

    @discardableResult
    public func joinRoom(_ target: RoomTarget) async throws -> SocialRoom {
        await pause()
        let current = try await requireProfile()
        guard let resolved = try resolveRoomTarget(target, current: snapshot.room) else {
            return try requireRoom()
        }
        clearRoomTimer(current.room)
        var next = current
        next.room = .joined(roomId: resolved.id, joinedAt: now())
        updateAccount(next)
        return try requireRoom()
    }

    public func leaveRoom() async {
        await pause()
        syncSession(await effectiveSession())
        guard var next = account, let room = next.room else { return }
        clearRoomTimer(room)
        next.room = nil
        updateAccount(next)
    }

    // MARK: - Yerel veri (Ayarlar > Veri)

    /// Bu cihazda saklanan sosyal mock verisi (JSON). Bozuk ya da boş depo → boş belge.
    public func exportLocalData() -> Data {
        let document = MockSocialStore.readDocument(storage: storage)
        return MockSocialStore.encode(document, pretty: true) ?? Data()
    }

    /// Saklanan sosyal mock verisini (önizleme kimliği dahil) siler ve hesabı yeniden yükler.
    public func clearLocalData() async {
        storage.clear()
        load(await effectiveSession())
    }

    // MARK: - Yardımcılar

    /// Yapay gecikme; 0 ise askıya almaz.
    private func pause() async {
        guard delayMs > 0 else { return }
        try? await Task.sleep(for: .milliseconds(delayMs))
    }

    /// Gerçek oturum yoksa önizleme kimliği (varsa).
    private func effectiveSession() async -> String? {
        if let id = await sessionProvider() { return id }
        return MockSocialStore.readPreviewAccountId(storage: storage)
    }

    private func isUsernameTaken(_ username: String) -> Bool {
        if username == account?.profile.username { return false }
        return SimulatedUsers.reservedUsernames.contains(username)
            || SimulatedUsers.find(username: username) != nil
    }

    private func resolveFriendLookup(_ lookup: FriendLookup, profile: SocialProfile) throws -> SimulatedUser {
        let found: SimulatedUser?
        switch lookup {
        case let .username(raw):
            guard case let .valid(username) = SocialCalc.validateUsername(raw) else {
                throw SocialError(.invalidUsername)
            }
            if username == profile.username { throw SocialError(.cannotAddSelf) }
            found = SimulatedUsers.find(username: username)
        case let .inviteCode(raw):
            guard let code = SocialCalc.normalizeInviteCode(raw) else { throw SocialError(.invalidInviteCode) }
            if code == profile.inviteCode { throw SocialError(.cannotAddSelf) }
            found = SimulatedUsers.find(inviteCode: code)
        }
        guard let found else { throw SocialError(.userNotFound) }
        return found
    }

    /// İsteği listeden çıkarır; `accept` ise kişiyi arkadaş ekler.
    func resolveRequest(_ account: StoredAccount, _ request: FriendRequest, accept: Bool) -> StoredAccount {
        var next = account
        next.requests = account.requests.filter { $0.id != request.id }
        let isFriend = account.friends.contains { $0.userId == request.user.userId }
        if accept && !isFriend {
            next.friends = account.friends + [
                StoredFriend(userId: request.user.userId, username: request.user.username, friendsSince: now())
            ]
        }
        return next
    }

    /// nil: hedef zaten içinde olduğum oda.
    private func resolveRoomTarget(_ target: RoomTarget, current: SocialRoom?) throws -> SimulatedRoom? {
        switch target {
        case let .room(id):
            if current?.id == id { return nil }
            guard let room = SimulatedUsers.rooms.first(where: { $0.id == id }) else {
                throw SocialError(.roomNotFound)
            }
            return room
        case let .inviteCode(raw):
            guard let code = SocialCalc.normalizeInviteCode(raw) else { throw SocialError(.invalidInviteCode) }
            if current?.inviteCode == code { return nil }
            guard let room = SimulatedUsers.rooms.first(where: { $0.inviteCode == code }) else {
                throw SocialError(.roomNotFound)
            }
            return room
        }
    }

    // MARK: - Simülasyon

    private func startSimulation() {
        guard tickMs > 0, simulationTimer == nil else { return }
        // Abone yokken geçen süreyi yakala: durumlar bayatlayıp "çevrimdışı" görünmesin.
        let current = now()
        presences = presences.mapValues { SimulatedUsers.heartbeat($0, now: current) }
        if status == .ready { commit() }
        simulationTimer = scheduler.every(milliseconds: tickMs) { [weak self] in self?.tick() }
    }

    private func stopSimulation() {
        simulationTimer?.cancel()
        simulationTimer = nil
    }

    /// Bir simülasyon adımı: her simüle kullanıcı için bir rastgele sayı (`SimulatedUsers.users` sırası).
    func tick() {
        let current = now()
        var next: [String: SocialPresence] = [:]
        for user in SimulatedUsers.users {
            let before = presences[user.userId] ?? SimulatedUsers.initialPresence(user, now: current)
            next[user.userId] = SimulatedUsers.simulatePresence(before, random(), now: current)
        }
        presences = next
        if status == .ready { commit() }
    }
}
