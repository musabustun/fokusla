import Foundation
import Security

/// Spotify App Remote erişim token'ı ve sona erme zamanı. Token yalnızca cihazda, Keychain'de saklanır
/// (`UserDefaults` DEĞİL); sunucuya ya da başka bir yere gönderilmez. Saf değer tipi; birim testli.
public struct SpotifyTokenRecord: Codable, Equatable, Sendable {
    /// Spotify erişim token'ları yaklaşık 1 saat geçerlidir; App Remote dönüşü süreyi bildirmez.
    public static let defaultLifetime: TimeInterval = 3600
    /// Sona ermeye bu kadar kala token "geçersiz" sayılır (bağlantı denemesi sırasında bitmesin).
    public static let expirySkew: TimeInterval = 120

    public var accessToken: String
    public var expiresAt: Date

    public init(accessToken: String, issuedAt: Date, lifetime: TimeInterval = defaultLifetime) {
        self.accessToken = accessToken
        self.expiresAt = issuedAt.addingTimeInterval(lifetime)
    }

    /// Boş olmayan, süresi dolmamış ve saat geri alınmasına karşı makul (en fazla `defaultLifetime` ileride) mi?
    public func isValid(at now: Date) -> Bool {
        state(at: now) == .valid
    }

    public func state(at now: Date) -> SpotifyConnectionPolicy.TokenState {
        guard !accessToken.isEmpty else { return .missing }
        let remaining = expiresAt.timeIntervalSince(now)
        // Saat geri alındıysa (kalan süre olası en büyük ömürden fazla) kayda güvenilmez.
        guard remaining > Self.expirySkew, remaining <= Self.defaultLifetime + Self.expirySkew else {
            return .expired
        }
        return .valid
    }
}

/// Token kalıcı depolama sözleşmesi. Gerçek uygulama `KeychainSpotifyTokenStore`; testler bellek içi olanı kullanır.
public protocol SpotifyTokenStoring: Sendable {
    func load() -> SpotifyTokenRecord?
    /// Başarıyla yazıldıysa `true`.
    @discardableResult func save(_ record: SpotifyTokenRecord) -> Bool
    func clear()
}

/// Bellek içi depo (testler, önizlemeler). Kalıcı değildir.
public final class InMemorySpotifyTokenStore: SpotifyTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var record: SpotifyTokenRecord?

    public init(_ record: SpotifyTokenRecord? = nil) {
        self.record = record
    }

    public func load() -> SpotifyTokenRecord? { lock.withLock { record } }

    @discardableResult public func save(_ record: SpotifyTokenRecord) -> Bool {
        lock.withLock { self.record = record }
        return true
    }

    public func clear() { lock.withLock { record = nil } }
}

/// Keychain depolaması: genel parola öğesi, yalnızca bu cihaz (`ThisDeviceOnly`: iCloud Keychain'e
/// senkronlanmaz, yedeğe girmez) ve ilk kilit açılıştan sonra erişilebilir (arka plandan yeniden bağlanma için).
public struct KeychainSpotifyTokenStore: SpotifyTokenStoring {
    public static let defaultService = "com.musabustun.fokus.spotify"
    private static let account = "app-remote-access-token"

    private let service: String

    public init(service: String = Self.defaultService) {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    public func load() -> SpotifyTokenRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(SpotifyTokenRecord.self, from: data)
    }

    @discardableResult
    public func save(_ record: SpotifyTokenRecord) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        let update = SecItemUpdate(
            baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    public func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
