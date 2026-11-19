import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { Toggle } from './Toggle'

function Harness({ onChange }: { onChange?: (value: boolean) => void }) {
  const [checked, setChecked] = useState(false)
  return (
    <Toggle
      aria-label="iCloud senkronu"
      checked={checked}
      onChange={(next) => {
        setChecked(next)
        onChange?.(next)
      }}
    />
  )
}

describe('Toggle', () => {
  it('exposes switch semantics and toggles on click', async () => {
    const onChange = vi.fn()
    render(<Harness onChange={onChange} />)
    const toggle = screen.getByRole('switch', { name: 'iCloud senkronu' })
    expect(toggle).not.toBeChecked()
    await userEvent.click(toggle)
    expect(toggle).toBeChecked()
    expect(onChange).toHaveBeenLastCalledWith(true)
    await userEvent.click(toggle)
    expect(onChange).toHaveBeenLastCalledWith(false)
  })

  it('toggles with the keyboard (Space)', async () => {
    render(<Harness />)
    await userEvent.tab()
    expect(screen.getByRole('switch')).toHaveFocus()
    await userEvent.keyboard(' ')
    expect(screen.getByRole('switch')).toBeChecked()
  })

  it('does not fire onChange when disabled', async () => {
    const onChange = vi.fn()
    render(<Toggle aria-label="Kapalı" checked={false} onChange={onChange} disabled />)
    await userEvent.click(screen.getByRole('switch'))
    expect(onChange).not.toHaveBeenCalled()
  })
})
