import AuthenticationServices
import Foundation

/// Apple kimlik bilgisinin durumu (`ASAuthorizationAppleIDProvider.CredentialState`).
public enum AppleCredentialStatus: Sendable, Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
}

/// Başarılı "Apple ile Giriş"ten gelen kimlik. Ad/e-posta yalnızca İLK girişte gelir.
public struct AppleSignInIdentity: Sendable, Equatable {
    public var userId: String
    public var displayName: String?

    public init(userId: String, displayName: String? = nil) {
        self.userId = userId
        self.displayName = displayName
    }
}

/// "Apple ile Giriş" hataları. `canceled` kullanıcıya hata olarak gösterilmez.
public enum AppleSignInError: Error, Sendable, Equatable {
    case canceled
    case notAvailable
    case failed(String)

    /// Kullanıcıya gösterilecek Türkçe mesaj (`canceled` için `nil`).
    public var userMessage: String? {
        switch self {
        case .canceled: nil
        case .notAvailable: "Apple ile Giriş bu cihazda şu an kullanılamıyor. Şimdilik atlayabilirsin."
        case .failed: "Apple ile Giriş tamamlanamadı. Tekrar dene ya da şimdilik atla."
        }
    }
}

/// Kimlik doğrulama sözleşmesi (web `AuthService`). Giriş opsiyoneldir; uygulama girişsiz tam çalışır.
@MainActor
public protocol AuthService: AnyObject {
    /// Kayıtlı Apple kimliğinin güncel durumu. `revoked`/`notFound` → `appleUserId` temizlenir, veri silinmez.
    func credentialStatus(for appleUserId: String) async -> AppleCredentialStatus
}

/// Gerçek "Apple ile Giriş" servisi (AuthenticationServices).
@MainActor
public final class AppleAuthService: AuthService {
    public init() {}

    public func credentialStatus(for appleUserId: String) async -> AppleCredentialStatus {
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserId)
            switch state {
            case .authorized: return .authorized
            case .revoked: return .revoked
            case .notFound: return .notFound
            case .transferred: return .transferred
            @unknown default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    /// `SignInWithAppleButton(onCompletion:)` sonucunu kimliğe ya da hataya çevirir.
    public static func identity(
        from result: Result<ASAuthorization, any Error>
    ) -> Result<AppleSignInIdentity, AppleSignInError> {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return .failure(.failed("Beklenmeyen kimlik bilgisi türü"))
            }
            let name = credential.fullName.flatMap { components -> String? in
                let formatted = PersonNameComponentsFormatter().string(from: components)
                return formatted.isEmpty ? nil : formatted
            }
            return .success(AppleSignInIdentity(userId: credential.user, displayName: name))
        case let .failure(error):
            return .failure(mapError(error))
        }
    }

    /// `ASAuthorizationError` → `AppleSignInError`.
    public static func mapError(_ error: any Error) -> AppleSignInError {
        guard let authError = error as? ASAuthorizationError else {
            return .failed(error.localizedDescription)
        }
        switch authError.code {
        case .canceled: return .canceled
        case .notHandled, .unknown, .notInteractive: return .notAvailable
        default: return .failed(authError.localizedDescription)
        }
    }
}

/// Önizleme/test için sahte servis.
@MainActor
public final class MockAuthService: AuthService {
    public var status: AppleCredentialStatus

    public init(status: AppleCredentialStatus = .authorized) {
        self.status = status
    }

    public func credentialStatus(for appleUserId: String) async -> AppleCredentialStatus { status }
}
