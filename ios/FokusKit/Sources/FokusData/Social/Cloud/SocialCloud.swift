import FokusDomain
import Foundation

// `CloudSocialService`'in taşıma sözleşmesi. Üretimde `CloudKitSocialCloud`, testlerde/UI testlerinde
// `InMemorySocialCloud`. Kurallar (kim arkadaş, istek geçerli mi…) burada DEĞİL, serviste durur.

public enum SocialCloudAccount: Sendable, Hashable {
    case available(userId: String)
    case unavailable
}

public enum SocialCloudError: Error, Sendable, Hashable {
    /// Kayıt zaten var (başkası ya da başka cihazım yazmış).
    case conflict
    case notFound
    case permission
    case network
    case noAccount
    /// Kendi davetim.
    case ownInvite
    case other(String)
}

/// Cihazlarım arasında ortak, yalnız bana ait sosyal kimlik (private veritabanı).
public struct SocialIdentity: Sendable, Hashable, Codable {
    public var username: String
    /// Kartlarda görünen rastgele kimlik; iCloud/Apple kimliğiyle ilişkisi yoktur.
    public var personId: String
    public var mailbox: String
    public var privateKey: Data
    public var isDiscoverable: Bool
    /// Yanıtladığım (kabul/ret) mektuplar: mektubu yalnız göndereni silebilir.
    public var handledMailIds: [String]
    /// Engellenen kişiler: `personId` ve iCloud kayıt adları.
    public var blockedIds: [String]

    public init(
        username: String, personId: String, mailbox: String, privateKey: Data, isDiscoverable: Bool = true,
        handledMailIds: [String] = [], blockedIds: [String] = []
    ) {
        self.username = username
        self.personId = personId
        self.mailbox = mailbox
        self.privateKey = privateKey
        self.isDiscoverable = isDiscoverable
        self.handledMailIds = handledMailIds
        self.blockedIds = blockedIds
    }
}

/// Kullanıcı adı kaydı (public). Adın kendisi yoktur; `key` adın özetidir.
public struct SocialClaim: Sendable, Hashable {
    public var key: String
    /// Sunucunun yazdığı oluşturan; yazarken yok sayılır.
    public var ownerId: String
    public var publicKey: Data
    public var mailbox: String
    public var acceptsRequests: Bool

    public init(key: String, ownerId: String, publicKey: Data, mailbox: String, acceptsRequests: Bool) {
        self.key = key
        self.ownerId = ownerId
        self.publicKey = publicKey
        self.mailbox = mailbox
        self.acceptsRequests = acceptsRequests
    }
}

public struct SocialMail: Sendable, Hashable {
    public var id: String
    /// Sunucunun yazdığı gönderen (sahtelenemez).
    public var senderId: String
    public var sealed: Data
    public var createdAt: Date

    public init(id: String, senderId: String, sealed: Data, createdAt: Date) {
        self.id = id
        self.senderId = senderId
        self.sealed = sealed
        self.createdAt = createdAt
    }
}

public enum SocialSpaceKind: String, Sendable, Hashable {
    /// Tek kullanımlık davet, iki kişi.
    case friend
    /// Bağlantısı olan herkes.
    case room
}

public struct SocialSpaceID: Sendable, Hashable {
    public var name: String
    public var ownerName: String
    public var isMine: Bool

    public init(name: String, ownerName: String, isMine: Bool) {
        self.name = name
        self.ownerName = ownerName
        self.isMine = isMine
    }
}

public struct SocialSpaceInfo: Sendable, Hashable {
    public var kind: SocialSpaceKind
    /// Oda adı (arkadaşlıkta boş).
    public var name: String
    public var hostPersonId: String
    /// Kullanıcı adıyla gönderilen istekte alıcının adı.
    public var toUsername: String?
    public var mailId: String?
    public var createdAt: Date

    public init(
        kind: SocialSpaceKind, name: String = "", hostPersonId: String, toUsername: String? = nil,
        mailId: String? = nil, createdAt: Date
    ) {
        self.kind = kind
        self.name = name
        self.hostPersonId = hostPersonId
        self.toUsername = toUsername
        self.mailId = mailId
        self.createdAt = createdAt
    }
}

/// Ev sahibinin arkadaşlarına duyurduğu açık oda.
public struct SocialCardRoom: Sendable, Hashable {
    public var id: String
    public var name: String
    public var url: URL
    public var memberCount: Int
    public var focusingCount: Int

    public init(id: String, name: String, url: URL, memberCount: Int, focusingCount: Int) {
        self.id = id
        self.name = name
        self.url = url
        self.memberCount = memberCount
        self.focusingCount = focusingCount
    }
}

/// Bir kişinin bir alandaki kartı: başkalarına giden TEK bilgi.
public struct SocialCard: Sendable, Hashable {
    public var personId: String
    public var username: String
    public var presence: SocialPresence?
    public var joinedAt: Date
    public var leftAt: Date?
    public var room: SocialCardRoom?
    /// Sunucunun yazdığı oluşturan (yazarken yok sayılır); kendi kartımda `nil` olabilir.
    public var creatorId: String?

    public init(
        personId: String, username: String, presence: SocialPresence? = nil, joinedAt: Date, leftAt: Date? = nil,
        room: SocialCardRoom? = nil, creatorId: String? = nil
    ) {
        self.personId = personId
        self.username = username
        self.presence = presence
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.room = room
        self.creatorId = creatorId
    }
}

/// Paylaşılan alan (CloudKit: paylaşılan bölge).
public struct SocialSpace: Sendable, Hashable {
    public var id: SocialSpaceID
    public var info: SocialSpaceInfo
    public var cards: [SocialCard]
    /// Arkadaşlık: yalnız benimkinde ve kullanılmamışken. Oda: her üyede.
    public var inviteURL: URL?

    public init(id: SocialSpaceID, info: SocialSpaceInfo, cards: [SocialCard], inviteURL: URL?) {
        self.id = id
        self.info = info
        self.cards = cards
        self.inviteURL = inviteURL
    }

    func card(of personId: String) -> SocialCard? { cards.first { $0.personId == personId } }
    func activeCards() -> [SocialCard] { cards.filter { $0.leftAt == nil } }
}

public protocol SocialCloud: Sendable {
    func account() async throws -> SocialCloudAccount

    func loadIdentity() async throws -> SocialIdentity?
    func saveIdentity(_ identity: SocialIdentity) async throws
    func deleteIdentity() async throws

    func claim(forKey key: String) async throws -> SocialClaim?
    /// Hata: conflict (kayıt zaten var).
    func createClaim(_ claim: SocialClaim) async throws
    /// Yalnız kendi kaydım. Hata: permission, notFound.
    func updateClaim(_ claim: SocialClaim) async throws
    func deleteClaim(key: String) async throws

    func sendMail(id: String, mailbox: String, sealed: Data) async throws
    func mail(in mailbox: String) async throws -> [SocialMail]
    /// Yalnız gönderen silebilir.
    func deleteMail(id: String) async throws

    /// Alanı, kartımı ve paylaşımı oluşturur; `inviteURL` dolu döner.
    func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard) async throws -> SocialSpace
    /// Benim ve bana paylaşılan tüm alanlar.
    func spaces() async throws -> [SocialSpace]
    func updateInfo(_ info: SocialSpaceInfo, in space: SocialSpaceID) async throws
    /// Kendi kartlarımı yazar; artık var olmayan alanlar sessizce atlanır.
    func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws
    /// Hata: notFound (geçersiz/kullanılmış), ownInvite.
    func acceptInvite(_ invite: SocialInvite) async throws -> SocialSpace
    /// Benimse siler; bana paylaşılmışsa paylaşımdan ayrılır. Yoksa hata vermez.
    func removeSpace(_ id: SocialSpaceID) async throws
}
