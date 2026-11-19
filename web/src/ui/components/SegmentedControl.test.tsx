import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { SegmentedControl } from './SegmentedControl'

type Mode = 'system' | 'light' | 'dark'

const OPTIONS = [
  { value: 'system', label: 'Sistem' },
  { value: 'light', label: 'Açık' },
  { value: 'dark', label: 'Koyu' },
] as const

function Harness({ onChange }: { onChange?: (value: Mode) => void }) {
  const [value, setValue] = useState<Mode>('system')
  return (
    <SegmentedControl
      aria-label="Tema"
      options={OPTIONS}
      value={value}
      onChange={(next) => {
        setValue(next)
        onChange?.(next)
      }}
    />
  )
}

describe('SegmentedControl', () => {
  it('exposes a labelled radiogroup with one checked radio', () => {
    render(<Harness />)
    expect(screen.getByRole('radiogroup', { name: 'Tema' })).toBeInTheDocument()
    expect(screen.getByRole('radio', { name: 'Sistem' })).toBeChecked()
    expect(screen.getByRole('radio', { name: 'Koyu' })).not.toBeChecked()
  })

  it('selects on click', async () => {
    const onChange = vi.fn()
    render(<Harness onChange={onChange} />)
    await userEvent.click(screen.getByRole('radio', { name: 'Koyu' }))
    expect(onChange).toHaveBeenCalledWith('dark')
    expect(screen.getByRole('radio', { name: 'Koyu' })).toBeChecked()
  })

  it('uses a roving tabindex and arrow keys with wrap-around', async () => {
    render(<Harness />)
    await userEvent.tab()
    expect(screen.getByRole('radio', { name: 'Sistem' })).toHaveFocus()
    expect(screen.getByRole('radio', { name: 'Açık' })).toHaveAttribute('tabindex', '-1')

    await userEvent.keyboard('{ArrowRight}')
    expect(screen.getByRole('radio', { name: 'Açık' })).toHaveFocus()
    expect(screen.getByRole('radio', { name: 'Açık' })).toBeChecked()

    await userEvent.keyboard('{ArrowLeft}{ArrowLeft}')
    expect(screen.getByRole('radio', { name: 'Koyu' })).toHaveFocus()
    expect(screen.getByRole('radio', { name: 'Koyu' })).toBeChecked()

    await userEvent.keyboard('{Home}')
    expect(screen.getByRole('radio', { name: 'Sistem' })).toBeChecked()
  })
})
