/**
 * Ayarlar ekranının yan etkili işlemleri. Ekrandan ayrıdır ki gerçek (Dexie) servislerle test
 * edilebilsin. Hepsi `useServices()` çıktısının bir alt kümesini alır.
 */
import { yksCurriculum } from '@/curriculum'
import { ensureCurriculumSeeded, type AppServices, type AuthSession } from '@/data'
import type { UserProfile, YksField } from '@/domain'

type Services = Pick<AppServices, 'auth' | 'sync' | 'repositories' | 'localData'>

/** "Apple ile Giriş" (mock) yapar ve Apple kimliğini profile bağlar. İptalde AuthCancelledError fırlar. */
export async function signInAndLink({
  auth,
  repositories,
}: Pick<Services, 'auth' | 'repositories'>): Promise<AuthSession> {
  const session = await auth.signInWithApple()
  const profile = await repositories.profiles.getCurrent()
  if (profile) {
    await repositories.profiles.update(profile.id, {
      appleUserId: session.appleUserId,
      displayName: profile.displayName ?? session.displayName,
    })
  }
  return session
}

/**
 * Oturumu kapatır (`deleteAccount` ise hesabı siler), senkronu kapatır ve profildeki Apple
 * bağını koparır. Yerel veriler (ve görünen ad) kalır.
 */
export async function signOutAndUnlink(
  { auth, sync, repositories }: Pick<Services, 'auth' | 'sync' | 'repositories'>,
  { deleteAccount }: { deleteAccount: boolean },
): Promise<void> {
  if (deleteAccount) await auth.deleteAccount()
  else await auth.signOut()
  await sync.disable()
  const profile = await repositories.profiles.getCurrent()
  if (profile?.appleUserId != null) {
    await repositories.profiles.update(profile.id, { appleUserId: null })
  }
}

/** Görünen adı kaydeder; boşluk-only girdi "ad yok" (null) demektir. */
export async function saveDisplayName(
  { repositories }: Pick<Services, 'repositories'>,
  profile: UserProfile,
  input: string,
): Promise<UserProfile> {
  const displayName = input.trim()
  return repositories.profiles.update(profile.id, { displayName: displayName || null })
}

/** YKS alanını değiştirir. Hiçbir veri silinmez; alan yalnızca ders görünürlüğünü belirler. */
export async function changeField(
  { repositories }: Pick<Services, 'repositories'>,
  profile: UserProfile,
  field: YksField,
): Promise<UserProfile> {
  if (profile.field === field) return profile
  return repositories.profiles.update(profile.id, { field })
}

/**
 * Cihazdaki TÜM veriyi kalıcı siler, oturumu kapatır, senkronu kapatır ve müfredat kataloğunu
 * yeniden tohumlar. Profil kalmadığı için onboarding kapısı kullanıcıyı /hos-geldin'e götürür.
 */
export async function wipeAllLocalData({
  auth,
  sync,
  repositories,
  localData,
}: Services): Promise<void> {
  await localData.deleteAll()
  await auth.signOut()
  await sync.disable()
  await ensureCurriculumSeeded(repositories, yksCurriculum)
}
