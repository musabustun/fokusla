import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { useMediaQuery } from './useMediaQuery'

function installMatchMedia(initial: boolean) {
  const listeners = new Set<() => void>()
  const state = { matches: initial }
  const matcher = {
    get matches() {
      return state.matches
    },
    addEventListener: (_: string, listener: () => void) => listeners.add(listener),
    removeEventListener: (_: string, listener: () => void) => listeners.delete(listener),
  }
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => matcher),
  )
  return {
    listeners,
    set(value: boolean) {
      state.matches = value
      listeners.forEach((listener) => listener())
    },
  }
}

describe('useMediaQuery', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('matchMedia yoksa false döner', () => {
    const { result } = renderHook(() => useMediaQuery('(min-width: 64rem)'))
    expect(result.current).toBe(false)
  })

  it('sorgu değişimini izler ve aboneliği kaldırır', () => {
    const media = installMatchMedia(true)
    const { result, unmount } = renderHook(() => useMediaQuery('(min-width: 64rem)'))
    expect(result.current).toBe(true)

    act(() => media.set(false))
    expect(result.current).toBe(false)

    unmount()
    expect(media.listeners.size).toBe(0)
  })
})
