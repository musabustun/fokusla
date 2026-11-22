import FokusDomain
import Foundation

// MockSocialService'in kalıcılığı (web `mockSocialStore.ts`). Saklanan JSON savunmacı biçimde
// ayrıştırılır: bozuk ya da yabancı veri boş belge sayılır, ASLA fırlatılmaz; geçersiz alt kayıtlar
// atlanır. Simüle kullanıcıların canlı durumları burada SAKLANMAZ. Tarihler ISO 8601 (ms) yazılır.

/// Arkadaş (kabul edilmiş).
public struct StoredFriend: Sendable, Hashable, Codable {
    public var userId: String
    public var username: String
    public var friendsSince: Date

    public init(userId: String, username: String, friendsSince: Date) {
        self.userId = userId
        self.username = username
        self.friendsSince = friendsSince
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        userId = try c.nonEmptyString(.userId)
        username = try c.nonEmptyString(.username)
        friendsSince = try c.decode(Date.self, forKey: .friendsSince)
    }
}

/// Açtığım odaya katılan simüle misafir.
public struct StoredRoomGuest: Sendable, Hashable, Codable {
    public var userId: String
    public var joinedAt: Date

    public init(userId: String, joinedAt: Date) {
        self.userId = userId
        self.joinedAt = joinedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        userId = try c.nonEmptyString(.userId)
        joinedAt = try c.decode(Date.self, forKey: .joinedAt)
    }
}

/// Ya simüle bir odaya katıldım ya da kendi odamı açtım.
public enum StoredRoom: Sendable, Hashable, Codable {
    case joined(roomId: String, joinedAt: Date)
    case hosted(id: String, name: String, inviteCode: String, createdAt: Date, guests: [StoredRoomGuest])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "joined":
            self = .joined(
                roomId: try c.nonEmptyString(.roomId), joinedAt: try c.decode(Date.self, forKey: .joinedAt))
        case "hosted":
            let guests = (try? c.decode([Lossy<StoredRoomGuest>].self, forKey: .guests)) ?? []
            self = .hosted(
                id: try c.nonEmptyString(.id), name: try c.nonEmptyString(.name),
                inviteCode: try c.nonEmptyString(.inviteCode),
                createdAt: try c.decode(Date.self, forKey: .createdAt), guests: guests.compactMap(\.value))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c, debugDescription: "Bilinmeyen oda türü")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: StoreKey.self)
        switch self {
        case let .joined(roomId, joinedAt):
            try c.encode("joined", forKey: .kind)
            try c.encode(roomId, forKey: .roomId)
            try c.encode(joinedAt, forKey: .joinedAt)
        case let .hosted(id, name, inviteCode, createdAt, guests):
            try c.encode("hosted", forKey: .kind)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(inviteCode, forKey: .inviteCode)
            try c.encode(createdAt, forKey: .createdAt)
            try c.encode(guests, forKey: .guests)
        }
    }
}

/// Bir Apple kullanıcısının sosyal hesabı.
public struct StoredAccount: Sendable, Hashable, Codable {
    public var profile: SocialProfile
    public var friends: [StoredFriend]
    public var requests: [FriendRequest]
    public var room: StoredRoom?
    /// Son yayınlanan kendi durumum (görünmezsem nil).
    public var selfPresence: SocialPresence?

    public init(
        profile: SocialProfile, friends: [StoredFriend] = [], requests: [FriendRequest] = [],
        room: StoredRoom? = nil, selfPresence: SocialPresence? = nil
    ) {
        self.profile = profile
        self.friends = friends
        self.requests = requests
        self.room = room
        self.selfPresence = selfPresence
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        profile = try c.decode(ValidProfile.self, forKey: .profile).value
        friends = ((try? c.decode([Lossy<StoredFriend>].self, forKey: .friends)) ?? []).compactMap(\.value)
        requests = ((try? c.decode([Lossy<ValidRequest>].self, forKey: .requests)) ?? [])
            .compactMap { $0.value?.value }
        room = (try? c.decode(Lossy<StoredRoom>.self, forKey: .room))?.value
        selfPresence = (try? c.decode(Lossy<ValidPresence>.self, forKey: .selfPresence))?.value?.value
    }
}

/// Saklanan belge: `{ version: 1, accounts: { <appleUserId>: StoredAccount }, previewAccountId? }`.
public struct StoredDocument: Sendable, Hashable, Codable {
    public static let currentVersion = 1
    public static let empty = StoredDocument(accounts: [:])

    public var version: Int
    /// Anahtar: Apple kullanıcı kimliği (ya da önizleme kimliği).
    public var accounts: [String: StoredAccount]
    /// `startPreviewSession()` ile açılan önizleme oturumunun kimliği.
    public var previewAccountId: String?

    public init(accounts: [String: StoredAccount], previewAccountId: String? = nil) {
        self.version = Self.currentVersion
        self.accounts = accounts
        self.previewAccountId = previewAccountId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        guard try c.decode(Int.self, forKey: .version) == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: c, debugDescription: "Desteklenmeyen sürüm")
        }
        version = Self.currentVersion
        let raw = try c.decode([String: Lossy<StoredAccount>].self, forKey: .accounts)
        accounts = raw.compactMapValues(\.value)
        let preview = try? c.decodeIfPresent(String.self, forKey: .previewAccountId)
        previewAccountId = preview.flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// Saklanan sosyal mock verisine okuma/yazma (depo soyutlaması üzerinden).
public enum MockSocialStore {
    public static let storageKey = UserDefaultsSocialStorage.defaultKey

    /// Saklanan belgeyi ayrıştırır; bozuk/yabancı veri için boş belge döner, asla fırlatmaz.
    public static func parseDocument(_ data: Data?) -> StoredDocument {
        guard let data else { return .empty }
        return (try? makeDecoder().decode(StoredDocument.self, from: data)) ?? .empty
    }

    /// Tek bir durum kaydını ayrıştırır; geçersizse nil.
    public static func parsePresence(_ data: Data) -> SocialPresence? {
        (try? makeDecoder().decode(ValidPresence.self, from: data))?.value
    }

    public static func readDocument(storage: any SocialStorage) -> StoredDocument {
        parseDocument(storage.load())
    }

    public static func readAccount(storage: any SocialStorage, appleUserId: String) -> StoredAccount? {
        readDocument(storage: storage).accounts[appleUserId]
    }

    /// Hesabı belgeye yazar; diğer hesaplar ve önizleme kimliği korunur.
    public static func writeAccount(
        storage: any SocialStorage, appleUserId: String, account: StoredAccount
    ) {
        var document = readDocument(storage: storage)
        document.accounts[appleUserId] = account
        write(document, to: storage)
    }

    public static func readPreviewAccountId(storage: any SocialStorage) -> String? {
        readDocument(storage: storage).previewAccountId
    }

    public static func writePreviewAccountId(storage: any SocialStorage, _ id: String?) {
        var document = readDocument(storage: storage)
        document.previewAccountId = id
        write(document, to: storage)
    }

    /// Belgeyi JSON'a çevirir (okunaklı, sıralı anahtarlar). Kodlanamazsa nil.
    public static func encode(_ document: StoredDocument, pretty: Bool = false) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return try? encoder.encode(document)
    }

    private static func write(_ document: StoredDocument, to storage: any SocialStorage) {
        guard let data = encode(document) else { return }
        storage.save(data)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseISODate(text) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Geçersiz ISO 8601 tarihi")
            }
            return date
        }
        return decoder
    }

    private static func parseISODate(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
}

// MARK: - Savunmacı ayrıştırma yardımcıları

enum StoreKey: String, CodingKey {
    case userId, username, inviteCode, isDiscoverable, friendsSince, id, direction, user, createdAt
    case joinedAt, roomId, kind, name, guests, state, sessionStartedAt, stateSince, todayFocusMs
    case updatedAt, version, accounts, previewAccountId, profile, friends, requests, room, selfPresence
}

extension KeyedDecodingContainer where Key == StoreKey {
    fileprivate func nonEmptyString(_ key: StoreKey) throws -> String {
        let value = try decode(String.self, forKey: key)
        guard !value.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Boş metin")
        }
        return value
    }
}

/// Dizi/sözlük öğesi ayrıştırılamazsa `nil` olur; kapsayıcıyı bozmaz.
struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private func decodeUser(_ c: KeyedDecodingContainer<StoreKey>) throws -> SocialUser {
    SocialUser(userId: try c.nonEmptyString(.userId), username: try c.nonEmptyString(.username))
}

private struct ValidProfile: Decodable {
    let value: SocialProfile

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        let user = try decodeUser(c)
        value = SocialProfile(
            userId: user.userId, username: user.username, inviteCode: try c.nonEmptyString(.inviteCode),
            isDiscoverable: try c.decode(Bool.self, forKey: .isDiscoverable))
    }
}

private struct ValidRequest: Decodable {
    let value: FriendRequest

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        let userContainer = try c.nestedContainer(keyedBy: StoreKey.self, forKey: .user)
        value = FriendRequest(
            id: try c.nonEmptyString(.id),
            direction: try c.decode(FriendRequestDirection.self, forKey: .direction),
            user: try decodeUser(userContainer), createdAt: try c.decode(Date.self, forKey: .createdAt))
    }
}

struct ValidPresence: Decodable {
    let value: SocialPresence

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: StoreKey.self)
        let focusMs = try c.decode(Double.self, forKey: .todayFocusMs)
        guard focusMs.isFinite, focusMs >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .todayFocusMs, in: c, debugDescription: "Geçersiz süre")
        }
        value = SocialPresence(
            state: try c.decode(PresenceState.self, forKey: .state),
            sessionStartedAt: try c.decodeIfPresent(Date.self, forKey: .sessionStartedAt),
            stateSince: try c.decodeIfPresent(Date.self, forKey: .stateSince), todayFocusMs: focusMs,
            updatedAt: try c.decode(Date.self, forKey: .updatedAt))
    }
}
