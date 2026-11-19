import { useSyncExternalStore } from 'react'

/** iPad yatay ve üstü: liste + detay yan yana. Tailwind `lg` kırılımıyla aynı. */
export const WIDE_LAYOUT_QUERY = '(min-width: 1024px)'

function query(): MediaQueryList | null {
  return typeof window.matchMedia === 'function' ? window.matchMedia(WIDE_LAYOUT_QUERY) : null
}

function subscribe(onChange: () => void): () => void {
  const mql = query()
  if (!mql) return () => undefined
  mql.addEventListener('change', onChange)
  return () => mql.removeEventListener('change', onChange)
}

function getSnapshot(): boolean {
  return query()?.matches ?? false
}

/** true: liste + detay yan yana (≥1024px). matchMedia yoksa (jsdom) false → iPhone düzeni. */
export function useWideLayout(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, () => false)
}
