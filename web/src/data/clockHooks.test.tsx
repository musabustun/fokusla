import { act, renderHook, waitFor } from '@testing-library/react'
import type { ReactNode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createTestServices, type TestServices } from '@/test/services'
import { msUntilNextLocalMidnight, useLocalToday, useNow, useSocialSnapshot } from './hooks'
import { ServicesProvider } from './ServicesContext'
import type { AppServices } from './services'
import type { SocialService, SocialSnapshot } from './social/SocialService'

describe('msUntilNextLocalMidnight', () => {
  it.each([
    ['gün ortası', new Date(2026, 10, 19, 12, 0, 0), 12 * 3600_000 + 1000],
    ['gece yarısından hemen önce', new Date(2026, 10, 19, 23, 59, 59), 2000],
    ['tam gece yarısı', new Date(2026, 10, 19, 0, 0, 0), 24 * 3600_000 + 1000],
  ])('%s', (_name, now, expected) => {
    expect(msUntilNextLocalMidnight(now)).toBe(expected)
  })
})

describe('useNow', () => {
  afterEach(() => vi.useRealTimers())

  it('ticks at the given interval and stops after unmount', () => {
    vi.useFakeTimers({ now: new Date(2026, 10, 19, 10, 0, 0) })
    const { result, unmount } = renderHook(() => useNow(1000))
    const first = result.current.getTime()

    act(() => vi.advanceTimersByTime(3000))
    expect(result.current.getTime() - first).toBe(3000)

    unmount()
    expect(vi.getTimerCount()).toBe(0)
  })
})

describe('useLocalToday', () => {
  afterEach(() => vi.useRealTimers())

  it('rolls over at local midnight', () => {
    vi.useFakeTimers({ now: new Date(2026, 10, 19, 23, 59, 0) })
    const { result } = renderHook(() => useLocalToday())
    expect(result.current).toBe('2026-11-19')

    act(() => vi.advanceTimersByTime(2 * 60_000))
    expect(result.current).toBe('2026-11-20')
  })

  it('refreshes when the tab becomes visible again', () => {
    vi.useFakeTimers({ now: new Date(2026, 10, 19, 22, 0, 0) })
    const { result, unmount } = renderHook(() => useLocalToday())

    // Uyku: zamanlayıcılar çalışmadan saat ilerler.
    vi.setSystemTime(new Date(2026, 10, 21, 8, 0, 0))
    act(() => {
      document.dispatchEvent(new Event('visibilitychange'))
    })
    expect(result.current).toBe('2026-11-21')

    unmount()
    expect(vi.getTimerCount()).toBe(0)
  })
})

describe('useSocialSnapshot', () => {
  let ctx: TestServices | undefined

  afterEach(async () => {
    await ctx?.dispose()
    ctx = undefined
    vi.restoreAllMocks()
  })

  function wrapperFor(services: AppServices) {
    return ({ children }: { children: ReactNode }) => (
      <ServicesProvider services={services}>{children}</ServicesProvider>
    )
  }

  it('refreshes the social service and follows its snapshot', async () => {
    ctx = createTestServices()
    const { result } = renderHook(() => useSocialSnapshot(), {
      wrapper: wrapperFor(ctx.services),
    })
    await waitFor(() => expect(result.current.status).toBe('signedOut'))
  })

  it('logs refresh failures instead of throwing', async () => {
    ctx = createTestServices()
    const snapshot = ctx.services.social.getSnapshot()
    const failing: SocialService = {
      ...ctx.services.social,
      getSnapshot: (): SocialSnapshot => snapshot,
      subscribe: () => () => undefined,
      refresh: () => Promise.reject(new Error('ağ yok')),
    }
    const log = vi.spyOn(console, 'error').mockImplementation(() => undefined)
    const { result } = renderHook(() => useSocialSnapshot(), {
      wrapper: wrapperFor({ ...ctx.services, social: failing }),
    })
    expect(result.current).toBe(snapshot)
    await waitFor(() =>
      expect(log).toHaveBeenCalledWith('Sosyal durum okunamadı', expect.any(Error)),
    )
  })
})
