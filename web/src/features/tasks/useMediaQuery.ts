import { useCallback, useSyncExternalStore } from 'react'

function getMatcher(query: string): MediaQueryList | null {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return null
  return window.matchMedia(query)
}

/** CSS medya sorgusunu izler. `matchMedia` yoksa (jsdom, SSR) false döner. */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const matcher = getMatcher(query)
      if (!matcher) return () => undefined
      matcher.addEventListener('change', onChange)
      return () => matcher.removeEventListener('change', onChange)
    },
    [query],
  )
  const getSnapshot = useCallback(() => getMatcher(query)?.matches ?? false, [query])
  return useSyncExternalStore(subscribe, getSnapshot, () => false)
}
