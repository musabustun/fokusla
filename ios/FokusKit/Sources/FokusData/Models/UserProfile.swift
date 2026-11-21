import FokusDomain
import Foundation
import SwiftData

/// Kullanıcı profili (web `UserProfile`). Cihaz başına tek profil beklenir; iki cihazda ayrı
/// onboarding yapılırsa `ProfileRepository.current()` en eskisini seçer.
@Model
public final class UserProfile: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var displayName: String?
    public var fieldRaw: String = "SAY"
    /// "Apple ile Giriş" kimliği (`ASAuthorizationAppleIDCredential.user`). Girişsiz kullanımda `nil`.
    public var appleUserId: String?
    public var targetExamYear: Int?
    public var onboardingCompletedAt: Date?

    public init(
        id: UUID = UUID(),
        displayName: String? = nil,
        field: YksField = .say,
        appleUserId: String? = nil,
        targetExamYear: Int? = nil,
        onboardingCompletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.fieldRaw = field.rawValue
        self.appleUserId = appleUserId
        self.targetExamYear = targetExamYear
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    /// Alan; bilinmeyen raw value `.say` sayılır.
    public var field: YksField {
        get { YksField(rawValue: fieldRaw) ?? .say }
        set { fieldRaw = newValue.rawValue }
    }
}
