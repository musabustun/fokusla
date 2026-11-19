const DARK_QUERY = '(prefers-color-scheme: dark)'

function darkQuery(): MediaQueryList | null {
  return typeof window.matchMedia === 'function' ? window.matchMedia(DARK_QUERY) : null
}

export function systemPrefersDark(): boolean {
  return darkQuery()?.matches ?? false
}

/** Sistem teması değiştiğinde çağrılır; aboneliği bırakan fonksiyonu döndürür. */
export function subscribeToSystemTheme(onChange: (prefersDark: boolean) => void): () => void {
  const query = darkQuery()
  if (!query) return () => undefined
  const listener = (event: MediaQueryListEvent) => onChange(event.matches)
  query.addEventListener('change', listener)
  return () => query.removeEventListener('change', listener)
}
