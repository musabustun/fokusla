import { resolveTheme, useThemeStore } from './themeStore'
import type { ResolvedTheme, ThemePreference } from './themeStorage'

export interface UseThemeResult {
  /** Kullanıcının seçimi: 'system' | 'light' | 'dark'. */
  preference: ThemePreference
  /** Gerçekte uygulanan tema. */
  resolved: ResolvedTheme
  setPreference: (preference: ThemePreference) => void
}

export function useTheme(): UseThemeResult {
  const preference = useThemeStore((state) => state.preference)
  const systemDark = useThemeStore((state) => state.systemDark)
  const setPreference = useThemeStore((state) => state.setPreference)
  return { preference, resolved: resolveTheme(preference, systemDark), setPreference }
}
