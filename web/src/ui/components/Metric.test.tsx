import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { inputStyles } from './inputStyles'
import { Metric } from './Metric'

describe('Metric', () => {
  it('renders label, value, unit and caption in reading order', () => {
    const { container } = render(
      <Metric label="Bugün" value="2:45" unit="sa" caption="Hedefin 3 sa" size="hero" />,
    )
    expect(container).toHaveTextContent('Bugün2:45saHedefin 3 sa')
    expect(screen.getByText('2:45').parentElement).toHaveClass('numeric', 'text-numeral-hero')
  })

  it('uses the accent ink only when asked', () => {
    render(<Metric label="Net" value="38,5" tone="accent" />)
    expect(screen.getByText('38,5').parentElement).toHaveClass('text-accent-ink', 'text-numeral-lg')
  })
})

describe('inputStyles', () => {
  it('keeps a 44px minimum height and an outlined, token-only look', () => {
    expect(inputStyles()).toContain('min-h-11')
    expect(inputStyles()).toContain('border-separator-strong')
    expect(inputStyles({ multiline: true })).toContain('min-h-24')
  })
})
