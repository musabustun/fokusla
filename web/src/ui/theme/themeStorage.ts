import { DEFAULT_PALETTE, isPaletteName, type PaletteName } from '../tokens'

/**
 * Görünüm tercihleri (mod + palet) cihaza özeldir (şimdilik senkronize edilmez) ve localStorage'da
 * tutulur. index.html'deki satır içi betik aynı anahtarları okuyarak ilk boyamada doğru temayı
 * uygular. Native: `@AppStorage("fokus.theme")` / `@AppStorage("fokus.palette")`.
 */
export type ThemePreference = 'system' | 'light' | 'dark'
export type ResolvedTheme = 'light' | 'dark'

export const THEME_STORAGE_KEY = 'fokus.theme'
export const PALETTE_STORAGE_KEY = 'fokus.palette'
/** Kayıtlı tercih yoksa: cihazın açık/koyu ayarını izle. */
export const DEFAULT_THEME_PREFERENCE: ThemePreference = 'system'
export const THEME_PREFERENCES: readonly ThemePreference[] = ['system', 'light', 'dark']

export function isThemePreference(value: unknown): value is ThemePreference {
  return typeof value === 'string' && (THEME_PREFERENCES as readonly string[]).includes(value)
}

function readStored<T extends string>(
  key: string,
  isValid: (value: unknown) => value is T,
  fallback: T,
): T {
  try {
    const stored = window.localStorage.getItem(key)
    return isValid(stored) ? stored : fallback
  } catch {
    // Gizli mod / depolama kapalı: varsayılan.
    return fallback
  }
}

function writeStored(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value)
  } catch (error) {
    console.warn('Görünüm tercihi kaydedilemedi', error)
  }
}

export function readStoredPreference(): ThemePreference {
  return readStored(THEME_STORAGE_KEY, isThemePreference, DEFAULT_THEME_PREFERENCE)
}

export function writeStoredPreference(preference: ThemePreference): void {
  writeStored(THEME_STORAGE_KEY, preference)
}

export function readStoredPalette(): PaletteName {
  return readStored(PALETTE_STORAGE_KEY, isPaletteName, DEFAULT_PALETTE)
}

export function writeStoredPalette(palette: PaletteName): void {
  writeStored(PALETTE_STORAGE_KEY, palette)
}
