import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import type { NetTrendPoint, TestSummary } from '@/domain/calc/tests'
import { NetTrendChart } from './NetTrendChart'

function point(date: string, net: number): NetTrendPoint {
  const summary: TestSummary = {
    testCount: 1,
    totalQuestions: 20,
    correct: 0,
    wrong: 0,
    blank: 0,
    net,
    accuracy: 0,
    netRatio: 0,
    lastTakenAt: null,
  }
  return { date, summary }
}

describe('NetTrendChart', () => {
  it('nokta yoksa hiçbir şey çizmez', () => {
    const { container } = render(<NetTrendChart points={[]} label="Net trendi" />)
    expect(container).toBeEmptyDOMElement()
  })

  it('özet erişilebilir ad, gizli tablo ve uç etiketleri gösterir', () => {
    const points = [point('2026-11-17', 4), point('2026-11-18', -1.25), point('2026-11-19', 12.75)]
    const { container } = render(<NetTrendChart points={points} label="Net trendi" />)

    expect(screen.getByRole('img', { name: 'Net trendi: 3 gün, son net 12,75' })).toBeVisible()
    const table = screen.getByRole('table', { name: 'Net trendi' })
    const rows = within(table).getAllByRole('row')
    expect(rows).toHaveLength(4)
    expect(rows[2]).toHaveTextContent('18 Kas-1,25')
    expect(container.querySelectorAll('[data-testid="trend-point"]')).toHaveLength(3)
    expect(container.querySelector('path[fill="none"]')).not.toBeNull()
    // Eksen uçları (0 dahil): en büyük net ve en küçük net.
    const img = screen.getByRole('img')
    expect(img).toHaveTextContent('12,75')
    expect(img).toHaveTextContent('-1,25')
    expect(img).toHaveTextContent('17 Kas')
    expect(img).toHaveTextContent('19 Kas')
  })

  it('tek noktada çizgi yerine yalnızca nokta çizer, eksen 0 içerir', () => {
    const { container } = render(<NetTrendChart points={[point('2026-11-19', 6)]} label="Trend" />)
    expect(screen.getByRole('img', { name: 'Trend: 1 gün, son net 6,00' })).toBeVisible()
    expect(container.querySelectorAll('[data-testid="trend-point"]')).toHaveLength(1)
    expect(container.querySelector('path[fill="none"]')).toBeNull()
    expect(screen.getByRole('img')).toHaveTextContent('0,00')
  })
})
