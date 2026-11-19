import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { ListRow } from './ListRow'
import { ListSection } from './ListSection'
import { Switch } from './Switch'

function ControlledSwitch({ initial = false }: { initial?: boolean }) {
  const [checked, setChecked] = useState(initial)
  return <Switch aria-label="Bildirimler" checked={checked} onChange={setChecked} />
}

describe('Switch', () => {
  it('renders an accessible switch button reflecting the checked state', () => {
    const { rerender } = render(
      <Switch aria-label="Bildirimler" checked={false} onChange={vi.fn()} />,
    )
    const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
    expect(toggle.tagName).toBe('BUTTON')
    expect(toggle).toHaveAttribute('type', 'button')
    expect(toggle).toHaveAttribute('aria-checked', 'false')

    rerender(<Switch aria-label="Bildirimler" checked onChange={vi.fn()} />)
    expect(toggle).toHaveAttribute('aria-checked', 'true')
  })

  it.each([
    [false, true],
    [true, false],
  ])('clicking when checked=%s calls onChange(%s)', async (checked, expected) => {
    const onChange = vi.fn()
    render(<Switch aria-label="Bildirimler" checked={checked} onChange={onChange} />)
    await userEvent.click(screen.getByRole('switch', { name: 'Bildirimler' }))
    expect(onChange).toHaveBeenCalledExactlyOnceWith(expected)
  })

  it.each(['{Enter}', ' '])('toggles from the keyboard with %j', async (key) => {
    render(<ControlledSwitch />)
    const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
    await userEvent.tab()
    expect(toggle).toHaveFocus()
    await userEvent.keyboard(key)
    expect(toggle).toHaveAttribute('aria-checked', 'true')
    await userEvent.keyboard(key)
    expect(toggle).toHaveAttribute('aria-checked', 'false')
  })

  it('does not change or take focus when disabled', async () => {
    const onChange = vi.fn()
    render(<Switch aria-label="Bildirimler" checked={false} onChange={onChange} disabled />)
    const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
    expect(toggle).toBeDisabled()
    await userEvent.click(toggle)
    await userEvent.tab()
    expect(toggle).not.toHaveFocus()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('can be labelled and described by other elements (e.g. inside a ListRow)', () => {
    render(
      <ListSection header="Sosyal">
        <ListRow
          title={<span id="presence-title">Durumumu paylaş</span>}
          subtitle={<span id="presence-hint">Arkadaşların odakta olduğunu görür</span>}
          accessory={
            <Switch
              aria-labelledby="presence-title"
              aria-describedby="presence-hint"
              checked
              onChange={vi.fn()}
            />
          }
        />
      </ListSection>,
    )
    const toggle = screen.getByRole('switch', { name: 'Durumumu paylaş' })
    expect(toggle).toHaveAccessibleDescription('Arkadaşların odakta olduğunu görür')
    expect(toggle).toBeChecked()
  })

  it('forwards id and className', () => {
    render(
      <Switch
        aria-label="Bildirimler"
        id="notifications"
        className="ml-2"
        checked={false}
        onChange={vi.fn()}
      />,
    )
    const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
    expect(toggle).toHaveAttribute('id', 'notifications')
    expect(toggle).toHaveClass('ml-2')
  })

  it('keeps a 44px hit area and disables motion under prefers-reduced-motion', () => {
    render(<Switch aria-label="Bildirimler" checked onChange={vi.fn()} />)
    const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
    expect(toggle).toHaveClass('min-h-11', 'min-w-11')
    const thumb = toggle.querySelector('[data-switch-thumb]')
    expect(thumb).toHaveClass('motion-reduce:transition-none')
  })

  it.each([
    [false, 'bg-fill', 'bg-switch-thumb-off', 'translate-x-0'],
    [true, 'bg-accent', 'bg-accent-contrast', 'translate-x-5'],
  ])(
    'checked=%s uses token colors and moves the thumb (state not by color alone)',
    (checked, trackClass, thumbClass, positionClass) => {
      render(<Switch aria-label="Bildirimler" checked={checked} onChange={vi.fn()} />)
      const toggle = screen.getByRole('switch', { name: 'Bildirimler' })
      const track = toggle.querySelector('[data-switch-track]')
      const thumb = toggle.querySelector('[data-switch-thumb]')
      expect(track).toHaveClass(trackClass)
      expect(track).toHaveAttribute('aria-hidden', 'true')
      expect(thumb).toHaveClass(thumbClass, positionClass)
    },
  )
})
