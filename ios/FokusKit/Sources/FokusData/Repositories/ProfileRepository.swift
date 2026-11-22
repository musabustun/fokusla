import FokusDomain
import Foundation
import SwiftData

/// Profil okuma/yazma. Sahibi: onboarding (oluşturma) ve settings (düzenleme) modülleri.
@MainActor
public struct ProfileRepository {
    private let store: EntityStore<UserProfile>

    public init(context: ModelContext) {
        store = EntityStore(context: context)
    }

    /// Geçerli profil: silinmemişlerden en eski `createdAt`'li olan (iki cihazda ayrı onboarding
    /// yapıldıysa deterministik seçim). Yoksa `nil`.
    public func current() throws -> UserProfile? {
        try store.all().min { $0.createdAt < $1.createdAt }
    }

    /// Onboarding tamamlandı mı?
    public func isOnboardingComplete() throws -> Bool {
        try current()?.onboardingCompletedAt != nil
    }

    /// Onboarding'i tamamlar: profil yoksa oluşturur, varsa günceller; `onboardingCompletedAt = now`.
    @discardableResult
    public func completeOnboarding(
        field: YksField,
        appleUserId: String?,
        displayName: String?,
        now: Date = .now
    ) throws -> UserProfile {
        let profile: UserProfile
        if let existing = try current() {
            profile = existing
            store.touch(profile, now: now)
        } else {
            profile = store.insert(UserProfile(), now: now)
        }
        profile.field = field
        if let appleUserId { profile.appleUserId = appleUserId }
        if let displayName, !displayName.isEmpty { profile.displayName = displayName }
        profile.onboardingCompletedAt = now
        try store.save()
        return profile
    }

    /// Apple kimliğini bağlar (`nil` → bağı kaldırır; veri silinmez).
    public func setAppleUserId(_ appleUserId: String?, now: Date = .now) throws {
        guard let profile = try current() else { return }
        profile.appleUserId = appleUserId
        store.touch(profile, now: now)
        try store.save()
    }

    /// Görünen adı kaydeder; boşluk-only girdi "ad yok" (`nil`) demektir. En çok `displayNameMaxLength` karakter.
    public func setDisplayName(_ input: String, now: Date = .now) throws {
        guard let profile = try current() else { return }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.displayNameMaxLength))
        store.touch(profile, now: now)
        try store.save()
    }

    /// YKS alanını değiştirir. Hiçbir veri silinmez; alan yalnızca ders görünürlüğünü belirler.
    public func setField(_ field: YksField, now: Date = .now) throws {
        guard let profile = try current(), profile.field != field else { return }
        profile.field = field
        store.touch(profile, now: now)
        try store.save()
    }

    /// Günlük odak hedefini ayarlar (dakika; `nil`/geçersiz → kapalı). Değer `DailyGoalCalc` ile normalize edilir.
    public func setDailyFocusGoal(minutes: Int?, now: Date = .now) throws {
        guard let profile = try current() else { return }
        profile.dailyFocusGoalMinutes = DailyGoalCalc.normalized(minutes)
        store.touch(profile, now: now)
        try store.save()
    }

    /// Görünen ad azami uzunluğu (web `DISPLAY_NAME_MAX_LENGTH` ile aynı).
    public static let displayNameMaxLength = 40
}
