import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { clampProgress } from './clampProgress'
import { ProgressRing } from './ProgressRing'

describe('ProgressRing', () => {
  it('exposes progressbar semantics with percentage values', () => {
    render(<ProgressRing value={0.456} label="Günlük odak hedefi" />)
    const bar = screen.getByRole('progressbar', { name: 'Günlük odak hedefi' })
    expect(bar).toHaveAttribute('aria-valuenow', '46')
    expect(bar).toHaveAttribute('aria-valuemin', '0')
    expect(bar).toHaveAttribute('aria-valuemax', '100')
  })

  it.each([
    [1.7, '100'],
    [-0.2, '0'],
    [Number.NaN, '0'],
  ])('clamps %s to aria-valuenow %s', (value, expected) => {
    render(<ProgressRing value={value} label="İlerleme" />)
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', expected)
  })

  it('hides only the ring graphic when no label is given; children stay accessible', () => {
    const { container } = render(
      <ProgressRing value={0.5}>
        <span role="timer" aria-label="Oturum süresi">
          12:00
        </span>
      </ProgressRing>,
    )
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    expect(container.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
    expect(screen.getByRole('timer', { name: 'Oturum süresi' })).toHaveTextContent('12:00')
  })

  it('clampProgress handles infinities', () => {
    expect(clampProgress(Number.POSITIVE_INFINITY)).toBe(0)
    expect(clampProgress(0.25)).toBe(0.25)
  })
})
