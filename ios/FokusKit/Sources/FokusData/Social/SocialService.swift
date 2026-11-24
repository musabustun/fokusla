import FokusDomain
import Foundation

// Sosyal sözleşmesi (web `data/social/SocialService.ts`): profil, arkadaşlık istekleri, arkadaş listesi
// ve paralel odak odaları. Uygulama `CloudSocialService` + `CloudKitSocialCloud` kullanır
// (docs/social-cloudkit.md). `MockSocialService` web prototipinin karşılığıdır; uygulamada kullanılmaz.
//
// Gizlilik (çoğu kullanıcı 18 yaş altı): başkalarına YALNIZCA kullanıcı adı ve odak durumu/süreleri
// (`SocialPresence`) gider. Apple kimliği, ad, e-posta ve çalışma içeriği paylaşılmaz.

/// - loading: henüz `refresh()` çalışmadı. signedOut: giriş yok → Sosyal kapalı.
/// - needsUsername: giriş var, kullanıcı adı seçilmemiş. ready: profil hazır.
/// - iCloudUnavailable: cihazda iCloud hesabı yok/kısıtlı. unreachable: hiç yüklenemedi (ağ vb.).
public enum SocialStatus: Sendable, Hashable {
    case loading, signedOut, needsUsername, ready, iCloudUnavailable, unreachable
}

/// Başka kullanıcıların görebildiği TEK kimlik bilgisi.
public struct SocialUser: Sendable, Hashable, Codable {
    /// Uygulama içi kimlik (CloudKit user record name). Kullanıcıya gösterilmez.
    public var userId: String
    public var username: String

    public init(userId: String, username: String) {
        self.userId = userId
        self.username = username
    }
}

public struct SocialProfile: Sendable, Hashable, Codable {
    public var userId: String
    public var username: String
    /// 6 karakterlik davet kodu (A–Z, 0–9); kullanıcı adı gizliyken de arkadaş eklemeye yarar.
    public var inviteCode: String
    /// "Sosyalde görün": false ise arkadaşlar beni çevrimdışı görür ve adımla aranamam.
    public var isDiscoverable: Bool

    public init(userId: String, username: String, inviteCode: String, isDiscoverable: Bool) {
        self.userId = userId
        self.username = username
        self.inviteCode = inviteCode
        self.isDiscoverable = isDiscoverable
    }
}

public struct SocialFriend: Sendable, Hashable, Identifiable {
    public var userId: String
    public var username: String
    /// nil: arkadaş gizlenmiş ya da hiç durum yayınlamamış (çevrimdışı gösterilir).
    public var presence: SocialPresence?
    public var friendsSince: Date

    public var id: String { userId }

    public init(userId: String, username: String, presence: SocialPresence?, friendsSince: Date) {
        self.userId = userId
        self.username = username
        self.presence = presence
        self.friendsSince = friendsSince
    }
}

public enum FriendRequestDirection: String, Sendable, Hashable, Codable {
    case incoming, outgoing
}

public struct FriendRequest: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var direction: FriendRequestDirection
    /// incoming: isteği gönderen; outgoing: isteğin gönderildiği kişi.
    public var user: SocialUser
    public var createdAt: Date

    public init(id: String, direction: FriendRequestDirection, user: SocialUser, createdAt: Date) {
        self.id = id
        self.direction = direction
        self.user = user
        self.createdAt = createdAt
    }
}

public struct RoomMember: Sendable, Hashable, Identifiable {
    public var userId: String
    public var username: String
    public var isSelf: Bool
    public var isHost: Bool
    /// Kendi satırım için UI, odak verisinden hesaplanan güncel durumu kullanır.
    public var presence: SocialPresence?
    public var joinedAt: Date

    public var id: String { userId }

    public init(
        userId: String, username: String, isSelf: Bool, isHost: Bool,
        presence: SocialPresence?, joinedAt: Date
    ) {
        self.userId = userId
        self.username = username
        self.isSelf = isSelf
        self.isHost = isHost
        self.presence = presence
        self.joinedAt = joinedAt
    }
}

/// İçinde bulunduğum paralel odak odası. Aynı anda en fazla bir odada olunur.
public struct SocialRoom: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var hostUserId: String
    public var inviteCode: String
    /// Sıra: ev sahibi, sonra katılma zamanına göre.
    public var members: [RoomMember]
    public var createdAt: Date
    /// Bağlantısı olan herkesin katılabildiği davet adresi (CloudKit paylaşımı).
    public var inviteURL: URL?

    public init(
        id: String, name: String, hostUserId: String, inviteCode: String,
        members: [RoomMember], createdAt: Date, inviteURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.hostUserId = hostUserId
        self.inviteCode = inviteCode
        self.members = members
        self.createdAt = createdAt
        self.inviteURL = inviteURL
    }
}

/// Arkadaşların açık, katılınabilir odaları (içinde olmadığım).
public struct RoomSummary: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var host: SocialUser
    public var memberCount: Int
    /// Şu an odakta olan üye sayısı.
    public var focusingCount: Int

    public init(id: String, name: String, host: SocialUser, memberCount: Int, focusingCount: Int) {
        self.id = id
        self.name = name
        self.host = host
        self.memberCount = memberCount
        self.focusingCount = focusingCount
    }
}

public struct SocialSnapshot: Sendable, Hashable {
    public var status: SocialStatus
    /// `status == .ready` iken dolu; diğer durumlarda nil.
    public var profile: SocialProfile?
    /// Kabul edilmiş arkadaşlar, kullanıcı adına göre (Türkçe) sıralı.
    public var friends: [SocialFriend]
    /// Bekleyen istekler (gelen + giden), yeniden eskiye.
    public var requests: [FriendRequest]
    public var room: SocialRoom?
    public var friendRooms: [RoomSummary]
    /// Henüz kullanılmamış, tek kullanımlık davet bağlantılarım (yeniden eskiye).
    public var pendingInvites: [FriendInvite]
    /// Son yenileme başarısız oldu; gösterilenler son bilinen değerlerdir.
    public var isOffline: Bool

    public init(
        status: SocialStatus, profile: SocialProfile? = nil, friends: [SocialFriend] = [],
        requests: [FriendRequest] = [], room: SocialRoom? = nil, friendRooms: [RoomSummary] = [],
        pendingInvites: [FriendInvite] = [], isOffline: Bool = false
    ) {
        self.status = status
        self.profile = profile
        self.friends = friends
        self.requests = requests
        self.room = room
        self.friendRooms = friendRooms
        self.pendingInvites = pendingInvites
        self.isOffline = isOffline
    }

    public static func empty(_ status: SocialStatus) -> SocialSnapshot { SocialSnapshot(status: status) }
}

public enum UsernameCheck: Sendable, Hashable {
    case ok(String)
    case invalid(UsernameProblem)
    case taken
}

/// Arkadaş ekleme: kullanıcı adıyla ya da davet koduyla.
public enum FriendLookup: Sendable, Hashable {
    case username(String)
    case inviteCode(String)
}

public enum RoomTarget: Sendable, Hashable {
    case room(id: String)
    case inviteCode(String)
}

public enum SocialErrorCode: String, Sendable, Hashable, CaseIterable {
    case notSignedIn, noProfile, invalidUsername, usernameTaken, invalidInviteCode, userNotFound
    case cannotAddSelf = "self"
    case alreadyFriends, requestExists, requestNotFound, friendNotFound, roomNotFound, invalidRoomName
    case iCloudUnavailable, network, inviteInvalid, roomFull, tooManyRequests, inappropriateText, unknown
}

/// Sosyal işlemlerin beklenen hataları. UI `code`'a göre Türkçe mesaj gösterir.
public struct SocialError: Error, Sendable, Hashable {
    public let code: SocialErrorCode

    public init(_ code: SocialErrorCode) {
        self.code = code
    }

    /// Kullanıcıya gösterilecek Türkçe mesaj (web `SOCIAL_ERROR_MESSAGES`).
    public var userMessage: String {
        switch code {
        case .notSignedIn: "Sosyal özellikler için Apple ile giriş yapmalısın."
        case .noProfile: "Önce bir kullanıcı adı seç."
        case .invalidUsername: "Kullanıcı adı geçersiz."
        case .usernameTaken: "Bu kullanıcı adı alınmış. Başka bir tane dene."
        case .invalidInviteCode: "Davet kodu 6 karakter olmalı (harf ve rakam)."
        case .userNotFound: "Bu bilgilerle bir kullanıcı bulunamadı."
        case .cannotAddSelf: "Kendini arkadaş olarak ekleyemezsin."
        case .alreadyFriends: "Bu kişi zaten arkadaşın."
        case .requestExists: "Bu kişiyle bekleyen bir istek zaten var."
        case .requestNotFound: "İstek artık geçerli değil."
        case .friendNotFound: "Bu kişi artık arkadaş listende değil."
        case .roomNotFound: "Oda bulunamadı ya da kapanmış."
        case .invalidRoomName: "Oda adı 1–40 karakter olmalı."
        case .iCloudUnavailable: "Sosyal için bu cihazda iCloud'a giriş yapmalısın."
        case .network: "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
        case .inviteInvalid: "Bu davet bağlantısı geçersiz ya da daha önce kullanılmış."
        case .roomFull: "Bu oda dolu."
        case .tooManyRequests: "Çok fazla bekleyen davetin var. Önce bazılarını geri çek."
        case .inappropriateText: "Bu ad uygun değil. Başka bir ad dene."
        case .unknown: "Bir şeyler ters gitti. Lütfen tekrar dene."
        }
    }
}

/// Tek kullanımlık arkadaşlık daveti.
public struct FriendInvite: Sendable, Hashable, Identifiable {
    public var id: String
    public var url: URL
    public var createdAt: Date

    public init(id: String, url: URL, createdAt: Date) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
    }
}

/// Kabul edilen davetin sonucu.
public enum SocialInviteOutcome: Sendable, Hashable {
    case friend(username: String)
    case room(name: String)
}

/// Oda adı üst sınırı (karakter).
public let socialRoomNameMaxLength = 40

/// Sosyal servis sözleşmesi. `@Observable` somut sınıflar `snapshot` değişince SwiftUI'ı günceller.
@MainActor
public protocol SocialService: AnyObject {
    /// Güncel anlık görüntü. Değişince yeni değer atanır (değer tipi).
    var snapshot: SocialSnapshot { get }

    /// Sosyal ekranı görünür olunca çağrılır (referans sayımlı); ilk çağrıda simülasyon başlar.
    func activate()
    /// `activate()` ile eşleşir; son çağrıda simülasyon durur.
    func deactivate()

    /// Oturumu ve profili yeniden okur. Giriş/çıkıştan sonra çağrılır.
    func refresh() async
    /// Bu cihazda "önizleme" oturumu açar (gerçek Apple girişi olmadan Sosyal'i gezmek için).
    /// Gerçek servis bunu yok sayar. Ardından `refresh()` çağrılır.
    func startPreviewSession() async

    /// Biçim + tekillik kontrolü (mock: yerel liste; native: public DB araması).
    func checkUsername(_ raw: String) async -> UsernameCheck
    /// Kullanıcı adını alır (ilk kez) ya da değiştirir. Hata: invalidUsername, usernameTaken, notSignedIn.
    @discardableResult func claimUsername(_ raw: String) async throws -> SocialProfile
    func setDiscoverable(_ isDiscoverable: Bool) async throws

    /// Hata: invalidUsername, invalidInviteCode, userNotFound, self, alreadyFriends, requestExists.
    @discardableResult func sendFriendRequest(_ lookup: FriendLookup) async throws -> FriendRequest
    /// Gelen isteği kabul/ret. Hata: requestNotFound.
    func respondToRequest(id: String, accept: Bool) async throws
    /// Giden isteği geri çek. Hata: requestNotFound.
    func cancelRequest(id: String) async throws
    /// Hata: friendNotFound.
    func removeFriend(userId: String) async throws

    /// Yeni oda açar ve içine girer (önceki odadan çıkılır). Ad 1–40 karakter. Hata: invalidRoomName.
    @discardableResult func createRoom(name: String) async throws -> SocialRoom
    /// Arkadaşın odasına ya da davet koduyla bir odaya katılır. Hata: roomNotFound, invalidInviteCode.
    @discardableResult func joinRoom(_ target: RoomTarget) async throws -> SocialRoom
    /// Odadan çıkar; ev sahibi çıkarsa oda kapanır. Odada değilse bir şey yapmaz.
    func leaveRoom() async

    /// Kendi durumumu yayınlar (`SocialCalc.ownPresenceFromFocus` ile üretilir). `isDiscoverable`
    /// false ise hiçbir şey paylaşılmaz. Native: ~60 sn kalp atışı + durum değişiminde.
    func publishPresence(_ presence: SocialPresence) async throws

    /// Örnek dünyayı gezme (önizleme oturumu) destekleniyor mu?
    var supportsPreview: Bool { get }
    /// Tek kullanımlık arkadaşlık bağlantısı üretir. Hata: tooManyRequests, network.
    func createFriendInvite() async throws -> FriendInvite
    /// Kullanılmamış bağlantıyı geçersiz kılar. Hata: requestNotFound.
    func cancelInvite(id: String) async throws
    /// Arkadaşlık ya da oda davetini kabul eder. Hata: inviteInvalid, self, alreadyFriends, roomFull.
    @discardableResult func acceptInvite(_ invite: SocialInvite) async throws -> SocialInviteOutcome
    /// Arkadaşı siler ve engeller. Hata: friendNotFound.
    func blockFriend(userId: String) async throws
    /// Gelen isteği reddeder ve göndereni engeller. Hata: requestNotFound.
    func blockRequest(id: String) async throws
    /// Sosyal profilini, arkadaşlıkları ve kullanıcı adını kalıcı olarak siler.
    func deleteAccount() async throws
}

/// Davet bağlantısı bilmeyen servisler (`MockSocialService`) için varsayılanlar.
extension SocialService {
    public var supportsPreview: Bool { false }
    public func createFriendInvite() async throws -> FriendInvite { throw SocialError(.unknown) }
    public func cancelInvite(id: String) async throws { throw SocialError(.requestNotFound) }
    @discardableResult
    public func acceptInvite(_ invite: SocialInvite) async throws -> SocialInviteOutcome {
        throw SocialError(.inviteInvalid)
    }
    public func blockFriend(userId: String) async throws { try await removeFriend(userId: userId) }
    public func blockRequest(id: String) async throws { try await respondToRequest(id: id, accept: false) }
    public func deleteAccount() async throws { throw SocialError(.unknown) }
}
