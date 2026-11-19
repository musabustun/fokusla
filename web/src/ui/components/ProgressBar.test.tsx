import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { ProgressBar } from './ProgressBar'

describe('ProgressBar', () => {
  it('exposes progressbar semantics with percentage values', () => {
    render(<ProgressBar value={0.283} label="Kitap ilerlemesi" />)
    const bar = screen.getByRole('progressbar', { name: 'Kitap ilerlemesi' })
    expect(bar).toHaveAttribute('aria-valuenow', '28')
    expect(bar).toHaveAttribute('aria-valuemin', '0')
    expect(bar).toHaveAttribute('aria-valuemax', '100')
  })

  it.each([
    [1.7, '100', '100%'],
    [-0.2, '0', '0%'],
    [Number.NaN, '0', '0%'],
  ])('clamps %s to aria-valuenow %s', (value, expected, width) => {
    render(<ProgressBar value={value} label="İlerleme" />)
    const bar = screen.getByRole('progressbar')
    expect(bar).toHaveAttribute('aria-valuenow', expected)
    expect(bar.firstElementChild).toHaveStyle({ width })
  })

  it('is hidden from assistive tech when no label is given', () => {
    const { container } = render(<ProgressBar value={0.5} size="small" tone="success" />)
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    expect(container.firstElementChild).toHaveAttribute('aria-hidden', 'true')
    expect(container.firstElementChild).toHaveClass('h-1')
    expect(container.firstElementChild?.firstElementChild).toHaveClass('bg-success')
  })
})
