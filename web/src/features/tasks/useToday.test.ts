import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { msUntilNextMidnight, useToday } from './useToday'

describe('msUntilNextMidnight', () => {
  it.each([
    [new Date(2026, 10, 19, 23, 59, 0), 61_000],
    [new Date(2026, 10, 19, 0, 0, 0), 24 * 3600_000 + 1000],
    [new Date(2026, 11, 31, 23, 0, 0), 3600_000 + 1000],
  ])('%s → %i ms', (now, expected) => {
    expect(msUntilNextMidnight(now)).toBe(expected)
  })
})

describe('useToday', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date(2026, 10, 19, 23, 59, 0))
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  it('bugünün yerel gününü döner ve gece yarısında güncellenir', () => {
    const { result, unmount } = renderHook(() => useToday())
    expect(result.current).toBe('2026-11-19')

    act(() => {
      vi.advanceTimersByTime(61_000)
    })
    expect(result.current).toBe('2026-11-20')
    unmount()
  })

  it('sekme yeniden görünür olunca günü tazeler', () => {
    const { result } = renderHook(() => useToday())
    vi.setSystemTime(new Date(2026, 10, 21, 9, 0, 0))
    act(() => {
      document.dispatchEvent(new Event('visibilitychange'))
    })
    expect(result.current).toBe('2026-11-21')
  })
})
