import type { PaletteName } from '../tokens'
import { resolveTheme, useThemeStore } from './themeStore'
import type { ResolvedTheme, ThemePreference } from './themeStorage'

export interface UseThemeResult {
  /** Kullanıcının mod seçimi: 'system' | 'light' | 'dark'. */
  preference: ThemePreference
  /** Gerçekte uygulanan mod. */
  resolved: ResolvedTheme
  setPreference: (preference: ThemePreference) => void
  /** Renk teması (palet): Kahve, Tek renk, Çilek… Moddan bağımsızdır. */
  palette: PaletteName
  setPalette: (palette: PaletteName) => void
}

export function useTheme(): UseThemeResult {
  const preference = useThemeStore((state) => state.preference)
  const systemDark = useThemeStore((state) => state.systemDark)
  const setPreference = useThemeStore((state) => state.setPreference)
  const palette = useThemeStore((state) => state.palette)
  const setPalette = useThemeStore((state) => state.setPalette)
  return {
    preference,
    resolved: resolveTheme(preference, systemDark),
    setPreference,
    palette,
    setPalette,
  }
}
