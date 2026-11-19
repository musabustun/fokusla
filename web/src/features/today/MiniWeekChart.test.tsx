import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import type { DailyFocusTotal } from '@/domain/calc/focus'
import { MiniWeekChart } from './MiniWeekChart'

const MINUTE = 60_000

const TOTALS: DailyFocusTotal[] = [
  { day: '2026-11-12', focusMs: 0 },
  { day: '2026-11-13', focusMs: 30 * MINUTE },
  { day: '2026-11-14', focusMs: 0 },
  { day: '2026-11-15', focusMs: 90 * MINUTE },
  { day: '2026-11-16', focusMs: 0 },
  { day: '2026-11-17', focusMs: 45 * MINUTE },
  { day: '2026-11-18', focusMs: 65 * MINUTE },
]

describe('MiniWeekChart', () => {
  it('reads every day as "<gün>: <süre>" and marks today as the current date', () => {
    render(<MiniWeekChart totals={TOTALS} today="2026-11-18" />)

    const days = within(screen.getByRole('list', { name: 'Son 7 gün' })).getAllByRole('listitem')
    expect(days.map((day) => day.textContent)).toEqual([
      'PerPerşembe: 0 dk',
      'CumCuma: 30 dk',
      'CmtCumartesi: 0 dk',
      'PazPazar: 1 sa 30 dk',
      'PztPazartesi: 0 dk',
      'SalSalı: 45 dk',
      'ÇarÇarşamba: 1 sa 5 dk',
    ])
    expect(days.at(-1)).toHaveAttribute('aria-current', 'date')
    expect(days.slice(0, -1).some((day) => day.hasAttribute('aria-current'))).toBe(false)
    expect(screen.getByText('Son 7 gün toplam:')).toBeInTheDocument()
    expect(screen.getByText('Son 7 gün toplam:').parentElement).toHaveTextContent('3 sa 50 dk')
  })

  it('scales bars to the busiest day and keeps empty days flat', () => {
    render(<MiniWeekChart totals={TOTALS} today="2026-11-18" />)

    const bars = within(screen.getByRole('list', { name: 'Son 7 gün' }))
      .getAllByRole('listitem')
      .map((day) => day.querySelector<HTMLElement>('[data-bar]')?.style.height)
    expect(bars[0]).toBe('0%')
    expect(bars[3]).toBe('100%')
    expect(Number.parseFloat(bars[1] ?? '')).toBeCloseTo((30 / 90) * 100, 2)
  })

  it('renders all-zero weeks without bars', () => {
    const empty = TOTALS.map((total) => ({ ...total, focusMs: 0 }))
    render(<MiniWeekChart totals={empty} today="2026-11-18" />)

    const days = within(screen.getByRole('list', { name: 'Son 7 gün' })).getAllByRole('listitem')
    expect(days).toHaveLength(7)
    expect(screen.getByText('Son 7 gün toplam:').parentElement).toHaveTextContent('0 dk')
  })
})
