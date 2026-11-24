import Foundation

/// Çok kullanıcılı sahte CloudKit: testlerde, UI testlerinde ve önizlemede gerçek servisin iki tarafını
/// çalıştırmak için. CloudKit'in kurallarını taklit eder: kaydı yalnız oluşturanı değiştirir/siler, arkadaşlık
/// bağlantısı tek kullanımlıktır, sahip silince alan herkesten kalkar. Ağ yoktur.
public actor InMemorySocialServer {
    private struct Space {
        var ownerId: String
        var info: SocialSpaceInfo
        var cards: [String: SocialCard]
        var participants: Set<String>
        var url: URL
    }

    private struct StoredMail {
        var mailbox: String
        var mail: SocialMail
    }

    private var identities: [String: SocialIdentity] = [:]
    private var claims: [String: SocialClaim] = [:]
    private var mails: [String: StoredMail] = [:]
    private var spaces: [String: Space] = [:]
    private var offlineUsers: Set<String> = []
    private var accountlessUsers: Set<String> = []
    private let now: @Sendable () -> Date
    /// Başarılı yazma sayısı (testler: gereksiz yazma yapılmıyor mu?).
    public private(set) var writeCount = 0

    public init(now: @escaping @Sendable () -> Date = { Date() }) { self.now = now }

    // MARK: Test denetimleri

    public func setOffline(_ isOffline: Bool, user: String) {
        if isOffline { offlineUsers.insert(user) } else { offlineUsers.remove(user) }
    }

    public func setAccountless(_ value: Bool, user: String) {
        if value { accountlessUsers.insert(user) } else { accountlessUsers.remove(user) }
    }

    public var claimCount: Int { claims.count }
    public var mailCount: Int { mails.count }
    public var spaceCount: Int { spaces.count }
    /// Public'te duran her şeyin ham baytları (gizlilik testi).
    public var publicBytes: [Data] {
        claims.values.flatMap { [Data($0.key.utf8), Data($0.mailbox.utf8), $0.publicKey] }
            + mails.values.flatMap { [Data($0.mailbox.utf8), $0.mail.sealed] }
    }

    // MARK: Sunucu

    private func check(_ user: String) throws {
        if offlineUsers.contains(user) { throw SocialCloudError.network }
        if accountlessUsers.contains(user) { throw SocialCloudError.noAccount }
    }

    private func checkWrite(_ user: String) throws {
        try check(user)
        writeCount += 1
    }

    func account(_ user: String) throws -> SocialCloudAccount {
        if accountlessUsers.contains(user) { return .unavailable }
        try check(user)
        return .available(userId: user)
    }

    func identity(_ user: String) throws -> SocialIdentity? {
        try check(user)
        return identities[user]
    }

    func setIdentity(_ identity: SocialIdentity?, _ user: String) throws {
        try checkWrite(user)
        identities[user] = identity
    }

    func claim(_ key: String, _ user: String) throws -> SocialClaim? {
        try check(user)
        return claims[key]
    }

    func createClaim(_ claim: SocialClaim, _ user: String) throws {
        try checkWrite(user)
        guard claims[claim.key] == nil else { throw SocialCloudError.conflict }
        claims[claim.key] = claim.owned(by: user)
    }

    func updateClaim(_ claim: SocialClaim, _ user: String) throws {
        try checkWrite(user)
        guard let current = claims[claim.key] else { throw SocialCloudError.notFound }
        guard current.ownerId == user else { throw SocialCloudError.permission }
        claims[claim.key] = claim.owned(by: user)
    }

    func deleteClaim(_ key: String, _ user: String) throws {
        try checkWrite(user)
        guard let current = claims[key] else { return }
        guard current.ownerId == user else { throw SocialCloudError.permission }
        claims[key] = nil
    }

    func sendMail(id: String, mailbox: String, sealed: Data, _ user: String) throws {
        try checkWrite(user)
        mails[id] = StoredMail(
            mailbox: mailbox, mail: SocialMail(id: id, senderId: user, sealed: sealed, createdAt: now()))
    }

    func mail(in mailbox: String, _ user: String) throws -> [SocialMail] {
        try check(user)
        return mails.values.filter { $0.mailbox == mailbox }.map(\.mail).sorted { $0.createdAt > $1.createdAt }
    }

    func deleteMail(_ id: String, _ user: String) throws {
        try checkWrite(user)
        guard let stored = mails[id] else { return }
        guard stored.mail.senderId == user else { throw SocialCloudError.permission }
        mails[id] = nil
    }

    func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard, _ user: String) throws -> SocialSpace {
        try checkWrite(user)
        guard let url = URL(string: "https://www.icloud.com/share/\(UUID().uuidString.lowercased())#Fokus") else {
            throw SocialCloudError.other("url")
        }
        var mine = card
        mine.creatorId = user
        spaces[name] = Space(
            ownerId: user, info: info, cards: [card.personId: mine], participants: [], url: url)
        return try view(name, user)
    }

    func spaces(_ user: String) throws -> [SocialSpace] {
        try check(user)
        return try spaces.filter { $0.value.ownerId == user || $0.value.participants.contains(user) }
            .keys.sorted().map { try view($0, user) }
    }

    func updateInfo(_ info: SocialSpaceInfo, in name: String, _ user: String) throws {
        try checkWrite(user)
        guard spaces[name]?.ownerId == user else { throw SocialCloudError.notFound }
        spaces[name]?.info = info
    }

    func saveCards(_ cards: [SocialSpaceID: SocialCard], _ user: String) throws {
        try checkWrite(user)
        for (id, card) in cards {
            guard let space = spaces[id.name], space.ownerId == user || space.participants.contains(user) else { continue }
            var mine = card
            mine.creatorId = user
            spaces[id.name]?.cards[card.personId] = mine
        }
    }

    func accept(_ url: URL, _ user: String) throws -> SocialSpace {
        try checkWrite(user)
        guard let (name, space) = spaces.first(where: { $0.value.url == url }) else { throw SocialCloudError.notFound }
        if space.ownerId == user { throw SocialCloudError.ownInvite }
        if space.participants.contains(user) { return try view(name, user) }
        if space.info.kind == .friend, !space.participants.isEmpty { throw SocialCloudError.notFound }
        spaces[name]?.participants.insert(user)
        return try view(name, user)
    }

    func removeSpace(_ name: String, _ user: String) throws {
        try checkWrite(user)
        guard let space = spaces[name] else { return }
        if space.ownerId == user {
            spaces[name] = nil
        } else {
            spaces[name]?.participants.remove(user)
        }
    }

    private func view(_ name: String, _ user: String) throws -> SocialSpace {
        guard let space = spaces[name] else { throw SocialCloudError.notFound }
        let isMine = space.ownerId == user
        let showsURL = space.info.kind == .room || (isMine && space.participants.isEmpty)
        return SocialSpace(
            id: SocialSpaceID(name: name, ownerName: space.ownerId, isMine: isMine), info: space.info,
            cards: space.cards.values.sorted { $0.personId < $1.personId }, inviteURL: showsURL ? space.url : nil)
    }
}

extension SocialClaim {
    fileprivate func owned(by user: String) -> SocialClaim {
        var copy = self
        copy.ownerId = user
        return copy
    }
}

/// Sahte sunucunun bir iCloud hesabından görünümü.
public struct InMemorySocialCloud: SocialCloud {
    public let userId: String
    public let server: InMemorySocialServer

    public init(userId: String, server: InMemorySocialServer) {
        self.userId = userId
        self.server = server
    }

    public func account() async throws -> SocialCloudAccount { try await server.account(userId) }
    public func loadIdentity() async throws -> SocialIdentity? { try await server.identity(userId) }
    public func saveIdentity(_ identity: SocialIdentity) async throws { try await server.setIdentity(identity, userId) }
    public func deleteIdentity() async throws { try await server.setIdentity(nil, userId) }
    public func claim(forKey key: String) async throws -> SocialClaim? { try await server.claim(key, userId) }
    public func createClaim(_ claim: SocialClaim) async throws { try await server.createClaim(claim, userId) }
    public func updateClaim(_ claim: SocialClaim) async throws { try await server.updateClaim(claim, userId) }
    public func deleteClaim(key: String) async throws { try await server.deleteClaim(key, userId) }
    public func sendMail(id: String, mailbox: String, sealed: Data) async throws {
        try await server.sendMail(id: id, mailbox: mailbox, sealed: sealed, userId)
    }
    public func mail(in mailbox: String) async throws -> [SocialMail] { try await server.mail(in: mailbox, userId) }
    public func deleteMail(id: String) async throws { try await server.deleteMail(id, userId) }
    public func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard) async throws -> SocialSpace {
        try await server.createSpace(name: name, info: info, card: card, userId)
    }
    public func spaces() async throws -> [SocialSpace] { try await server.spaces(userId) }
    public func updateInfo(_ info: SocialSpaceInfo, in space: SocialSpaceID) async throws {
        try await server.updateInfo(info, in: space.name, userId)
    }
    public func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws { try await server.saveCards(cards, userId) }
    public func acceptInvite(_ invite: SocialInvite) async throws -> SocialSpace {
        guard case let .url(url) = invite.source else { throw SocialCloudError.notFound }
        return try await server.accept(url, userId)
    }
    public func removeSpace(_ id: SocialSpaceID) async throws { try await server.removeSpace(id.name, userId) }
}
