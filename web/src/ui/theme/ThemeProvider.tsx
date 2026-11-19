import { useEffect, type ReactNode } from 'react'
import { COLORS } from '../tokens'
import { subscribeToSystemTheme } from './systemTheme'
import { useThemeStore } from './themeStore'
import { useTheme } from './useTheme'

interface ThemeProviderProps {
  children: ReactNode
}

/**
 * Çözümlenen temayı `<html data-theme>`, `color-scheme` ve `<meta name="theme-color">` olarak
 * uygular; sistem temasını izler.
 * Uygulamada bir kez, en dışta kullanılır.
 */
export function ThemeProvider({ children }: ThemeProviderProps) {
  const { resolved } = useTheme()
  const setSystemDark = useThemeStore((state) => state.setSystemDark)

  useEffect(() => subscribeToSystemTheme(setSystemDark), [setSystemDark])

  useEffect(() => {
    const root = document.documentElement
    root.dataset.theme = resolved
    root.style.colorScheme = resolved
    // Tarayıcı/durum çubuğu rengi ekran zeminiyle aynı olsun.
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', COLORS[resolved].background)
  }, [resolved])

  return children
}
