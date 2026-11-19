import { useEffect, type ReactNode } from 'react'
import { subscribeToSystemTheme } from './systemTheme'
import { useThemeStore } from './themeStore'
import { useTheme } from './useTheme'

interface ThemeProviderProps {
  children: ReactNode
}

/**
 * Çözümlenen temayı `<html data-theme>` ve `color-scheme` olarak uygular; sistem temasını izler.
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
  }, [resolved])

  return children
}
