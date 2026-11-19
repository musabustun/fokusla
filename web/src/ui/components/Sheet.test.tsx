import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it } from 'vitest'
import { Button } from './Button'
import { Sheet } from './Sheet'

function Harness() {
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button onClick={() => setOpen(true)}>Yeni görev</Button>
      <Sheet
        open={open}
        onClose={() => setOpen(false)}
        title="Görev ekle"
        description="Bugün için bir görev"
      >
        <label>
          Başlık
          <input />
        </label>
      </Sheet>
    </>
  )
}

async function openSheet() {
  render(<Harness />)
  await userEvent.click(screen.getByRole('button', { name: 'Yeni görev' }))
  return screen.getByRole('dialog', { name: 'Görev ekle' })
}

describe('Sheet', () => {
  it('opens a labelled modal dialog and moves focus inside', async () => {
    const dialog = await openSheet()
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    expect(dialog).toHaveAccessibleDescription('Bugün için bir görev')
    expect(dialog).toContainElement(document.activeElement as HTMLElement)
  })

  it('closes on Escape and returns focus to the trigger', async () => {
    await openSheet()
    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Yeni görev' })).toHaveFocus()
  })

  it('closes with the close button', async () => {
    await openSheet()
    await userEvent.click(screen.getByRole('button', { name: 'Kapat' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Yeni görev' })).toHaveFocus()
  })

  it('does not render content while closed', () => {
    render(<Harness />)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.queryByLabelText('Başlık')).not.toBeInTheDocument()
  })
})
