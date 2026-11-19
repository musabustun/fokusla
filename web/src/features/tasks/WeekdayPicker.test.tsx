import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import type { Weekday } from '@/domain'
import { WeekdayPicker } from './WeekdayPicker'

function Harness({ initial, onChange }: { initial: Weekday[]; onChange: (v: Weekday[]) => void }) {
  const [value, setValue] = useState(initial)
  return (
    <WeekdayPicker
      value={value}
      onChange={(next) => {
        setValue(next)
        onChange(next)
      }}
    />
  )
}

describe('WeekdayPicker', () => {
  it('7 günü tam adlarıyla ve kısa etiketle gösterir', () => {
    render(<WeekdayPicker value={[1]} onChange={() => undefined} />)
    const group = screen.getByRole('group', { name: 'Günler' })
    const buttons = within(group).getAllByRole('button')
    expect(buttons.map((b) => b.getAttribute('aria-label'))).toEqual([
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ])
    expect(buttons.map((b) => b.textContent)).toEqual([
      'Pzt',
      'Sal',
      'Çar',
      'Per',
      'Cum',
      'Cmt',
      'Paz',
    ])
    expect(screen.getByRole('button', { name: 'Pazartesi' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('seçimi aç/kapa yapar ve sıralı döndürür', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    render(<Harness initial={[5]} onChange={onChange} />)

    await user.click(screen.getByRole('button', { name: 'Pazartesi' }))
    expect(onChange).toHaveBeenLastCalledWith([1, 5])
    expect(screen.getByRole('button', { name: 'Pazartesi' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    await user.click(screen.getByRole('button', { name: 'Cuma' }))
    expect(onChange).toHaveBeenLastCalledWith([1])
    expect(screen.getByRole('button', { name: 'Cuma' })).toHaveAttribute('aria-pressed', 'false')
  })
})
