/** Bugün odak halkası testleri (tablo tabanlı; Swift port'unda tekrar kullanılacak). */
import { describe, expect, it } from 'vitest'
import type { DailyFocusTotal } from './focus'
import { FOCUS_RING_LAP_MS, focusRingProgress } from './today'

const MIN = 60_000

function totals(...minutes: number[]): DailyFocusTotal[] {
  return minutes.map((m, i) => ({
    day: `2026-11-${String(12 + i).padStart(2, '0')}`,
    focusMs: m * MIN,
  }))
}

describe('focusRingProgress', () => {
  it('lap constant is one hour', () => {
    expect(FOCUS_RING_LAP_MS).toBe(60 * MIN)
  })

  const cases: readonly {
    name: string
    todayMin: number
    totals: DailyFocusTotal[]
    activeMin: number | null
    kind: 'sessionLap' | 'weekBest'
    value: number
  }[] = [
    {
      name: 'active 15 min → quarter lap',
      todayMin: 15,
      totals: totals(0, 60),
      activeMin: 15,
      kind: 'sessionLap',
      value: 0.25,
    },
    {
      name: 'active 0 → empty lap',
      todayMin: 0,
      totals: [],
      activeMin: 0,
      kind: 'sessionLap',
      value: 0,
    },
    {
      name: 'active 90 min → wraps to half',
      todayMin: 90,
      totals: [],
      activeMin: 90,
      kind: 'sessionLap',
      value: 0.5,
    },
    {
      name: 'active exactly 60 min → wraps to 0',
      todayMin: 60,
      totals: [],
      activeMin: 60,
      kind: 'sessionLap',
      value: 0,
    },
    {
      name: 'negative active clamps to 0',
      todayMin: 0,
      totals: [],
      activeMin: -5,
      kind: 'sessionLap',
      value: 0,
    },
    {
      name: 'idle, half of best day',
      todayMin: 45,
      totals: totals(90, 0, 45),
      activeMin: null,
      kind: 'weekBest',
      value: 0.5,
    },
    {
      name: 'idle, today is the best',
      todayMin: 120,
      totals: totals(30, 120),
      activeMin: null,
      kind: 'weekBest',
      value: 1,
    },
    {
      name: 'idle, today above chart max still ≤ 1',
      todayMin: 100,
      totals: totals(30, 50),
      activeMin: null,
      kind: 'weekBest',
      value: 1,
    },
    {
      name: 'idle, nothing at all',
      todayMin: 0,
      totals: totals(0, 0),
      activeMin: null,
      kind: 'weekBest',
      value: 0,
    },
    {
      name: 'idle, empty totals and no focus',
      todayMin: 0,
      totals: [],
      activeMin: null,
      kind: 'weekBest',
      value: 0,
    },
  ]

  it.each(cases)('$name', ({ todayMin, totals: list, activeMin, kind, value }) => {
    const result = focusRingProgress(
      todayMin * MIN,
      list,
      activeMin === null ? null : activeMin * MIN,
    )
    expect(result.kind).toBe(kind)
    expect(result.value).toBeCloseTo(value, 10)
  })
})
