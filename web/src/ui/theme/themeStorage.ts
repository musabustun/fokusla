/**
 * Tema tercihi cihaza özeldir (senkronize edilmez) ve localStorage'da tutulur.
 * index.html'deki satır içi betik aynı anahtarı okuyarak ilk boyamada doğru temayı uygular.
 */
export type ThemePreference = 'system' | 'light' | 'dark'
export type ResolvedTheme = 'light' | 'dark'

export const THEME_STORAGE_KEY = 'fokus.theme'
export const THEME_PREFERENCES: readonly ThemePreference[] = ['system', 'light', 'dark']

export function isThemePreference(value: unknown): value is ThemePreference {
  return typeof value === 'string' && (THEME_PREFERENCES as readonly string[]).includes(value)
}

export function readStoredPreference(): ThemePreference {
  try {
    const stored = window.localStorage.getItem(THEME_STORAGE_KEY)
    return isThemePreference(stored) ? stored : 'system'
  } catch {
    // Gizli mod / depolama kapalı: varsayılan sistem teması.
    return 'system'
  }
}

export function writeStoredPreference(preference: ThemePreference): void {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, preference)
  } catch (error) {
    console.warn('Tema tercihi kaydedilemedi', error)
  }
}
