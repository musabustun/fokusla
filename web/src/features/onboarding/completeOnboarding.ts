import { toISODateTime, type UserProfile, type YksField } from '@/domain'
import type { AuthSession, Repositories } from '@/data'

export interface CompleteOnboardingInput {
  field: YksField
  /** "Apple ile Giriş" yapıldıysa oturum; "Şimdilik atla" seçildiyse null. */
  session: AuthSession | null
}

/**
 * Onboarding seçimlerini cihazdaki tek profile yazar. Profil varsa günceller (ör. yarıda kalmış
 * bir onboarding), yoksa oluşturur. Atlanan girişte mevcut Apple kimliği silinmez.
 */
export async function completeOnboarding(
  repositories: Pick<Repositories, 'profiles'>,
  { field, session }: CompleteOnboardingInput,
  now: Date = new Date(),
): Promise<UserProfile> {
  const existing = await repositories.profiles.getCurrent()
  const changes = {
    field,
    appleUserId: session?.appleUserId ?? existing?.appleUserId ?? null,
    displayName: session?.displayName ?? existing?.displayName ?? null,
    onboardingCompletedAt: toISODateTime(now),
  }
  if (existing) {
    return repositories.profiles.update(existing.id, changes)
  }
  return repositories.profiles.create({ ...changes, targetExamYear: null })
}

/** Profil onboarding'i tamamlamış mı? */
export function isOnboarded(profile: UserProfile | undefined): profile is UserProfile {
  return profile?.onboardingCompletedAt != null
}
