import FokusDomain
import Foundation
import SwiftData

/// Apple "Apple ile Giriş" token'ını iptal etme sözleşmesi.
///
/// Apple, hesap silinen uygulamaların token'ı iptal etmesini ister (`POST appleid.apple.com/auth/revoke`).
/// Bu uç nokta, geliştirici anahtarıyla imzalanmış bir `client_secret` JWT'si gerektirir; anahtar
/// uygulamaya GÖMÜLEMEZ ve Fokus'un sunucusu yoktur. Bu yüzden varsayılan uygulama (`ManualAppleTokenRevoker`)
/// iptali yapamaz ve kullanıcıyı yönlendirir. İleride bir iptal uç noktası eklenirse yalnızca bu protokolün
/// yeni bir uygulaması yazılır; çağıranlar değişmez.
@MainActor
public protocol AppleTokenRevoker: AnyObject {
    /// Token'ı iptal etmeyi dener. İptal edilebildiyse `true`; kullanıcının elle yapması gerekiyorsa `false`.
    func revoke(appleUserId: String) async -> Bool
}

/// Sunucu olmadığı için iptal EDEMEZ; kullanıcı Ayarlar › Apple Hesabı › "Apple ile Giriş Kullanan
/// Uygulamalar" › Fokus › "Apple ile Giriş'i Durdur" yolunu izler.
@MainActor
public final class ManualAppleTokenRevoker: AppleTokenRevoker {
    public init() {}
    public func revoke(appleUserId: String) async -> Bool { false }
}

/// Test için: sonucu belirlenebilir ve çağrıları kaydeder.
@MainActor
public final class MockAppleTokenRevoker: AppleTokenRevoker {
    public var result: Bool
    public private(set) var revokedUserIds: [String] = []

    public init(result: Bool = true) { self.result = result }

    public func revoke(appleUserId: String) async -> Bool {
        revokedUserIds.append(appleUserId)
        return result
    }
}

/// Hesap silme sonucu.
public enum AccountDeletionOutcome: Sendable, Equatable {
    /// Apple token'ı iptal edildi.
    case revoked
    /// Yerel bağ kaldırıldı; token iptali kullanıcının sistem ayarlarından yapması gerekiyor.
    case manualRevocationNeeded
    /// Silinecek bir Apple hesabı bağı yoktu.
    case nothingLinked
}

/// Giriş/çıkış/hesap silme (web `actions.ts` karşılığı). Yerel veriler ASLA silinmez; bu ayrı
/// ve çift onaylı bir adımdır (`LocalDataService.deleteAll`).
@MainActor
public struct AccountService {
    private let context: ModelContext
    private let sync: (any SyncService)?
    private let revoker: any AppleTokenRevoker

    public init(context: ModelContext, sync: (any SyncService)?, revoker: any AppleTokenRevoker = ManualAppleTokenRevoker()) {
        self.context = context
        self.sync = sync
        self.revoker = revoker
    }

    /// "Apple ile Giriş" sonucunu profile bağlar; profilde ad yoksa Apple'dan geleni yazar.
    public func link(_ identity: AppleSignInIdentity, now: Date = .now) throws {
        let repository = ProfileRepository(context: context)
        try repository.setAppleUserId(identity.userId, now: now)
        if let name = identity.displayName, try repository.current()?.displayName == nil {
            try repository.setDisplayName(name, now: now)
        }
    }

    /// Çıkış: iCloud eşitlemeyi kapatır, Apple bağını koparır. Yerel veriler ve görünen ad kalır.
    public func signOut(now: Date = .now) throws {
        sync?.setEnabled(false)
        try ProfileRepository(context: context).setAppleUserId(nil, now: now)
    }

    /// Hesabı siler: token iptalini dener, ardından çıkış yapar. Yerel veriler kalır.
    @discardableResult
    public func deleteAccount(now: Date = .now) async throws -> AccountDeletionOutcome {
        guard let appleUserId = try ProfileRepository(context: context).current()?.appleUserId else {
            sync?.setEnabled(false)
            return .nothingLinked
        }
        let revoked = await revoker.revoke(appleUserId: appleUserId)
        try signOut(now: now)
        return revoked ? .revoked : .manualRevocationNeeded
    }
}
