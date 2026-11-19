import { create } from 'zustand'
import type { PaletteName } from '../tokens'
import { systemPrefersDark } from './systemTheme'
import {
  readStoredPalette,
  readStoredPreference,
  writeStoredPalette,
  writeStoredPreference,
  type ResolvedTheme,
  type ThemePreference,
} from './themeStorage'

interface ThemeState {
  preference: ThemePreference
  palette: PaletteName
  systemDark: boolean
  setPreference: (preference: ThemePreference) => void
  setPalette: (palette: PaletteName) => void
  setSystemDark: (systemDark: boolean) => void
}

export const useThemeStore = create<ThemeState>()((set) => ({
  preference: readStoredPreference(),
  palette: readStoredPalette(),
  systemDark: systemPrefersDark(),
  setPreference: (preference) => {
    writeStoredPreference(preference)
    set({ preference })
  },
  setPalette: (palette) => {
    writeStoredPalette(palette)
    set({ palette })
  },
  setSystemDark: (systemDark) => set({ systemDark }),
}))

export function resolveTheme(preference: ThemePreference, systemDark: boolean): ResolvedTheme {
  if (preference === 'system') return systemDark ? 'dark' : 'light'
  return preference
}
