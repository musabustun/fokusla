import { create } from 'zustand'
import { systemPrefersDark } from './systemTheme'
import {
  readStoredPreference,
  writeStoredPreference,
  type ResolvedTheme,
  type ThemePreference,
} from './themeStorage'

interface ThemeState {
  preference: ThemePreference
  systemDark: boolean
  setPreference: (preference: ThemePreference) => void
  setSystemDark: (systemDark: boolean) => void
}

export const useThemeStore = create<ThemeState>()((set) => ({
  preference: readStoredPreference(),
  systemDark: systemPrefersDark(),
  setPreference: (preference) => {
    writeStoredPreference(preference)
    set({ preference })
  },
  setSystemDark: (systemDark) => set({ systemDark }),
}))

export function resolveTheme(preference: ThemePreference, systemDark: boolean): ResolvedTheme {
  if (preference === 'system') return systemDark ? 'dark' : 'light'
  return preference
}
