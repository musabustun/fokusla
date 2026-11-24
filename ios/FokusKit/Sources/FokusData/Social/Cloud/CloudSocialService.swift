import FokusDomain
import Foundation
import Observation
import OSLog

/// Gerçek sosyal servis: tüm kurallar burada, taşıma `SocialCloud`'dadır (docs/social-cloudkit.md).
/// İşlemler sıraya alınır (`exclusive`): yenileme ile değişiklik birbirinin üstüne yazmaz.
@MainActor
@Observable
public final class CloudSocialService: SocialService {
    public static let maxRoomMembers = 20
    public static let maxPendingInvites = 20
    static let maxIncomingMails = 50

    public private(set) var snapshot: SocialSnapshot = .empty(.loading)

    @ObservationIgnored let cloud: any SocialCloud
    @ObservationIgnored let now: @MainActor () -> Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let logger = Logger(subsystem: "com.musabustun.fokus", category: "social")
    @ObservationIgnored private let sessionProvider: @MainActor () async -> String?
    @ObservationIgnored private let scheduler: any SocialScheduler
    @ObservationIgnored private let pollMs: Int

    @ObservationIgnored var userId: String?
    @ObservationIgnored var identity: SocialIdentity?
    @ObservationIgnored var spaces: [SocialSpace] = []
    @ObservationIgnored var incoming: [IncomingMail] = []
    /// Kullanıcının son odak durumu; yeni kartlara da yazılır.
    @ObservationIgnored var ownPresence: SocialPresence?
    /// Son başarılı yayının içeriği (değişmeyen çevrimdışı durum yeniden yazılmaz).
    @ObservationIgnored var lastPublished: [SocialSpaceID: SocialCard] = [:]

    @ObservationIgnored private var isBusy = false
    @ObservationIgnored private var waiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var activationCount = 0
    @ObservationIgnored private var poll: SocialCancellable?

    /// - Parameters:
    ///   - sessionProvider: Apple kullanıcı kimliği (giriş yoksa nil). Her işlemde sorulur.
    ///   - pollMs: Sosyal görünürken yenileme aralığı. ≤ 0 → zamanlayıcı kurulmaz.
    public init(
        sessionProvider: @escaping @MainActor () async -> String?,
        cloud: any SocialCloud,
        scheduler: any SocialScheduler = TaskSocialScheduler(),
        now: @escaping @MainActor () -> Date = { Date() },
        calendar: Calendar = .current,
        pollMs: Int = 20_000
    ) {
        self.sessionProvider = sessionProvider
        self.cloud = cloud
        self.scheduler = scheduler
        self.now = now
        self.calendar = calendar
        self.pollMs = pollMs
    }

    // MARK: - Görünürlük

    public func activate() {
        activationCount += 1
        guard activationCount == 1, pollMs > 0 else { return }
        poll = scheduler.every(milliseconds: pollMs) { [weak self] in
            guard let self, !self.isBusy else { return }
            Task { await self.refresh() }
        }
    }

    public func deactivate() {
        guard activationCount > 0 else { return }
        activationCount -= 1
        if activationCount == 0 {
            poll?.cancel()
            poll = nil
        }
    }

    // MARK: - Oturum ve profil

    /// Gerçek serviste önizleme oturumu yoktur.
    public func startPreviewSession() async {}

    public func refresh() async {
        await exclusive { await self.reload() }
    }

    public func checkUsername(_ raw: String) async -> UsernameCheck {
        switch SocialCalc.validateUsername(raw) {
        case let .invalid(problem): return .invalid(problem)
        case let .valid(username):
            // Ağ hatasında "uygun" denir; kesin karar `claimUsername`'dedir (orada hata gösterilir).
            let claim = try? await cloud.claim(forKey: SocialDirectory.claimKey(forUsername: username))
            return claim.map { $0.ownerId == userId ? .ok(username) : .taken } ?? .ok(username)
        }
    }

    @discardableResult
    public func claimUsername(_ raw: String) async throws -> SocialProfile {
        try await exclusiveThrowing {
            guard case let .valid(username) = SocialCalc.validateUsername(raw) else { throw SocialError(.invalidUsername) }
            guard SocialContentFilter.isAcceptable(username) else { throw SocialError(.inappropriateText) }
            let userId = try await self.requireAccount()
            let existing = try await self.cloud.loadIdentity()
            var next = existing ?? SocialIdentity(
                username: username, personId: Self.newId(), mailbox: Self.newId(),
                privateKey: SocialMailCrypto.generatePrivateKey())
            let previous = existing?.username
            next.username = username
            try await self.writeClaim(for: next, userId: userId)
            try await self.cloud.saveIdentity(next)
            if let previous, previous != username { await self.releaseClaim(previous) }
            self.identity = next
            await self.reload()
            try? await self.publishCards(force: true)
            return SocialProfile(
                userId: next.personId, username: username, inviteCode: "", isDiscoverable: next.isDiscoverable)
        }
    }

    public func setDiscoverable(_ isDiscoverable: Bool) async throws {
        try await exclusiveThrowing {
            var next = try await self.requireIdentity()
            let userId = try await self.requireAccount()
            next.isDiscoverable = isDiscoverable
            try await self.writeClaim(for: next, userId: userId)
            try await self.cloud.saveIdentity(next)
            self.identity = next
            try await self.publishCards(force: true)
            self.rebuild()
        }
    }

    public func deleteAccount() async throws {
        try await exclusiveThrowing {
            _ = try await self.requireAccount()
            guard let identity = try await self.cloud.loadIdentity() else { return }
            self.identity = identity
            for space in try await self.cloud.spaces() { try await self.discard(space) }
            try await self.cloud.deleteClaim(key: SocialDirectory.claimKey(forUsername: identity.username))
            try await self.cloud.deleteIdentity()
            self.resetCaches()
            self.snapshot = .empty(.needsUsername)
        }
    }

    // MARK: - Yayın

    public func publishPresence(_ presence: SocialPresence) async throws {
        try await exclusiveThrowing {
            self.ownPresence = presence
            guard self.snapshot.status == .ready, self.identity?.isDiscoverable == true else { return }
            try await self.publishCards(force: false)
        }
    }

    /// Kendi kartımı bulunduğum her alana yazar. İçeriği değişmemiş çevrimdışı kart atlanır (kota).
    func publishCards(force: Bool) async throws {
        guard let identity else { return }
        var cards: [SocialSpaceID: SocialCard] = [:]
        for space in spaces {
            guard let current = space.card(of: identity.personId), current.leftAt == nil else { continue }
            guard let card = makeCard(joinedAt: current.joinedAt, kind: space.info.kind), force || needsPublish(card, in: space.id) else { continue }
            cards[space.id] = card
        }
        guard !cards.isEmpty else { return }
        try await cloud.saveCards(cards)
        lastPublished.merge(cards) { _, new in new }
        spaces = spaces.map { space in cards[space.id].map { space.replacing($0) } ?? space }
        rebuild()
    }

    private func needsPublish(_ card: SocialCard, in space: SocialSpaceID) -> Bool {
        guard let last = lastPublished[space], card.presence?.state == .offline || card.presence == nil else { return true }
        var comparable = card
        comparable.presence?.updatedAt = last.presence?.updatedAt ?? .distantPast
        return comparable != last
    }

    /// Paylaşılacak kartım. Açık odam yalnız arkadaşlara duyurulur; gizliyken durum ve oda hiç yazılmaz.
    func makeCard(joinedAt: Date, kind: SocialSpaceKind) -> SocialCard? {
        guard let identity else { return nil }
        let isVisible = identity.isDiscoverable
        let announcement = kind == .friend ? world(identity).roomAnnouncement(ownPresence: ownPresence) : nil
        return SocialCard(
            personId: identity.personId, username: identity.username,
            presence: isVisible ? ownPresence.map(SocialCalc.presenceForPublishing) : nil, joinedAt: joinedAt,
            room: isVisible ? announcement : nil)
    }

    // MARK: - Yükleme

    func reload() async {
        guard await sessionProvider() != nil else {
            resetCaches()
            snapshot = .empty(.signedOut)
            return
        }
        do {
            guard case let .available(userId) = try await cloud.account() else {
                resetCaches()
                snapshot = .empty(.iCloudUnavailable)
                return
            }
            if self.userId != userId { resetCaches() }
            self.userId = userId
            guard let identity = try await cloud.loadIdentity() else {
                resetCaches()
                self.userId = userId
                snapshot = .empty(.needsUsername)
                return
            }
            self.identity = identity
            spaces = try await cloud.spaces()
            incoming = try await loadIncoming(identity)
            try await reconcile(identity)
            rebuild()
        } catch {
            logger.error("Sosyal yenilenemedi: \(String(describing: error), privacy: .public)")
            handleReloadFailure(error)
        }
    }

    private func handleReloadFailure(_ error: any Error) {
        if error as? SocialCloudError == .noAccount {
            resetCaches()
            snapshot = .empty(.iCloudUnavailable)
        } else if snapshot.status == .ready {
            snapshot.isOffline = true
        } else {
            snapshot = .empty(.unreachable)
        }
    }

    func world(_ identity: SocialIdentity) -> SocialWorld {
        SocialWorld(identity: identity, spaces: spaces, incoming: incoming, now: now(), calendar: calendar)
    }

    func rebuild() {
        guard let identity else { return }
        snapshot = world(identity).snapshot(isOffline: false)
    }

    private func resetCaches() {
        userId = nil
        identity = nil
        spaces = []
        incoming = []
        lastPublished = [:]
    }

    /// Yarım kalan işleri toparlar: ayrılanları temizler, eksik kartı yazar, teslim edilen mektubu siler.
    private func reconcile(_ identity: SocialIdentity) async throws {
        let world = world(identity)
        for space in world.obsoleteSpaces { try await discard(space) }
        let missing = world.spacesMissingMyCard
        if !missing.isEmpty {
            let joinedAt = now()
            let cards = Dictionary(uniqueKeysWithValues: missing.compactMap { space in
                makeCard(joinedAt: joinedAt, kind: space.info.kind).map { (space.id, $0) }
            })
            try await cloud.saveCards(cards)
            spaces = spaces.map { space in cards[space.id].map { space.replacing($0) } ?? space }
        }
        for space in world.spacesWithDeliveredMail where spaces.contains(where: { $0.id == space.id }) {
            guard let mailId = space.info.mailId else { continue }
            try await cloud.deleteMail(id: mailId)
            var info = space.info
            info.mailId = nil
            try await cloud.updateInfo(info, in: space.id)
        }
    }

    /// Alanı bırakır: benimse (varsa mektubuyla) siler; değilse ayrıldığımı yazıp paylaşımdan çıkar.
    func discard(_ space: SocialSpace) async throws {
        if space.id.isMine {
            if let mailId = space.info.mailId { try await cloud.deleteMail(id: mailId) }
        } else if let mine = identity.flatMap({ space.card(of: $0.personId) }), mine.leftAt == nil {
            var left = mine
            left.leftAt = now()
            left.presence = nil
            left.room = nil
            try await cloud.saveCards([space.id: left])
        }
        try await cloud.removeSpace(space.id)
        spaces.removeAll { $0.id == space.id }
        lastPublished[space.id] = nil
    }

    // MARK: - Yardımcılar

    static func newId() -> String { Identifiers.lowercasedString(UUID()) }

    @discardableResult
    func requireAccount() async throws -> String {
        guard await sessionProvider() != nil else { throw SocialError(.notSignedIn) }
        guard case let .available(userId) = try await cloud.account() else { throw SocialError(.iCloudUnavailable) }
        self.userId = userId
        return userId
    }

    /// Güncel kimlik (diğer cihazımın yazdıkları dahil).
    func requireIdentity() async throws -> SocialIdentity {
        try await requireAccount()
        guard let identity = try await cloud.loadIdentity() else { throw SocialError(.noProfile) }
        self.identity = identity
        return identity
    }

    func saveIdentity(_ next: SocialIdentity) async throws {
        try await cloud.saveIdentity(next)
        identity = next
    }

    private func writeClaim(for identity: SocialIdentity, userId: String) async throws {
        let claim = SocialClaim(
            key: SocialDirectory.claimKey(forUsername: identity.username), ownerId: userId,
            publicKey: try SocialMailCrypto.publicKey(forPrivateKey: identity.privateKey), mailbox: identity.mailbox,
            acceptsRequests: identity.isDiscoverable)
        do {
            try await cloud.createClaim(claim)
        } catch SocialCloudError.conflict {
            // Kayıt benimse (yeniden kurulum, yarım kalmış deneme) güncellenir; değilse ad alınmıştır.
            guard try await cloud.claim(forKey: claim.key)?.ownerId == userId else { throw SocialError(.usernameTaken) }
            try await cloud.updateClaim(claim)
        }
    }

    private func releaseClaim(_ username: String) async {
        do {
            try await cloud.deleteClaim(key: SocialDirectory.claimKey(forUsername: username))
        } catch {
            logger.error("Eski kullanıcı adı bırakılamadı: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Sıraya alma ve hata çevirisi

    private func acquire() async {
        if !isBusy {
            isBusy = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty { isBusy = false } else { waiters.removeFirst().resume() }
    }

    private func exclusive(_ body: @MainActor () async -> Void) async {
        await acquire()
        defer { release() }
        await body()
    }

    /// Beklenmeyen taşıma hatalarını kullanıcıya gösterilebilir `SocialError`'a çevirir.
    func exclusiveThrowing<T: Sendable>(_ body: @MainActor () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        do {
            return try await body()
        } catch let error as SocialError {
            throw error
        } catch let error as SocialCloudError {
            logger.error("Sosyal işlem başarısız: \(String(describing: error), privacy: .public)")
            throw SocialError(error.socialCode)
        } catch {
            logger.error("Sosyal işlem başarısız: \(String(describing: error), privacy: .public)")
            throw SocialError(.unknown)
        }
    }
}

extension SocialCloudError {
    var socialCode: SocialErrorCode {
        switch self {
        case .network: .network
        case .noAccount: .iCloudUnavailable
        case .ownInvite: .cannotAddSelf
        case .conflict, .notFound, .permission, .other: .unknown
        }
    }
}

extension SocialSpace {
    func replacing(_ card: SocialCard) -> SocialSpace {
        var copy = self
        var next = card
        next.creatorId = copy.card(of: card.personId)?.creatorId
        copy.cards = copy.cards.filter { $0.personId != card.personId } + [next]
        return copy
    }
}
