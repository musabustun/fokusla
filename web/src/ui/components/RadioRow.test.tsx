import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it } from 'vitest'
import { RadioRow } from './RadioRow'

function Group() {
  const [value, setValue] = useState<string | null>(null)
  return (
    <fieldset>
      <legend>Alan</legend>
      {['SAY', 'EA'].map((option) => (
        <RadioRow
          key={option}
          name="alan"
          value={option}
          code={option}
          checked={value === option}
          onChange={() => setValue(option)}
          title={option === 'SAY' ? 'Sayısal' : 'Eşit Ağırlık'}
          description={`${option} açıklaması`}
        />
      ))}
    </fieldset>
  )
}

describe('RadioRow', () => {
  it('is a real, labelled radio with a description', () => {
    render(<Group />)
    const radio = screen.getByRole('radio', { name: 'Sayısal' })
    expect(radio).toHaveAccessibleDescription('SAY açıklaması')
    expect(radio).not.toBeChecked()
  })

  it('selects on click and moves between options with arrow keys', async () => {
    const user = userEvent.setup()
    render(<Group />)
    await user.click(screen.getByText('Sayısal'))
    expect(screen.getByRole('radio', { name: 'Sayısal' })).toBeChecked()
    await user.keyboard('{ArrowDown}')
    expect(screen.getByRole('radio', { name: 'Eşit Ağırlık' })).toBeChecked()
  })
})
