import { useEffect, type ReactNode } from 'react'
import { PALETTES } from '../tokens'
import { subscribeToSystemTheme } from './systemTheme'
import { useThemeStore } from './themeStore'
import { useTheme } from './useTheme'

interface ThemeProviderProps {
  children: ReactNode
}

/**
 * Çözümlenen modu `<html data-theme>` ve `color-scheme`, paleti `<html data-palette>` olarak;
 * ikisinin zemin rengini `<meta name="theme-color">` olarak uygular; sistem temasını izler.
 * Uygulamada bir kez, en dışta kullanılır.
 */
export function ThemeProvider({ children }: ThemeProviderProps) {
  const { resolved, palette } = useTheme()
  const setSystemDark = useThemeStore((state) => state.setSystemDark)

  useEffect(() => subscribeToSystemTheme(setSystemDark), [setSystemDark])

  useEffect(() => {
    const root = document.documentElement
    root.dataset.theme = resolved
    root.dataset.palette = palette
    root.style.colorScheme = resolved
    // Tarayıcı/durum çubuğu rengi ekran zeminiyle aynı olsun.
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', PALETTES[palette][resolved].background)
  }, [resolved, palette])

  return children
}
