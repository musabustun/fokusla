import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { PALETTE_LABELS, PALETTE_NAMES, type PaletteName } from '../tokens'
import { PalettePicker } from './PalettePicker'
import { PalettePreview } from './PalettePreview'

function ControlledPicker({ onChange }: { onChange?: (palette: PaletteName) => void }) {
  const [value, setValue] = useState<PaletteName>('coffee')
  return (
    <PalettePicker
      value={value}
      mode="dark"
      onChange={(palette) => {
        setValue(palette)
        onChange?.(palette)
      }}
    />
  )
}

describe('PalettePicker', () => {
  it('renders one named radio per palette inside a labelled group', () => {
    render(<ControlledPicker />)
    expect(screen.getByRole('group', { name: 'Renk teması' })).toBeInTheDocument()
    const radios = screen.getAllByRole('radio')
    expect(radios).toHaveLength(PALETTE_NAMES.length)
    for (const palette of PALETTE_NAMES) {
      expect(screen.getByRole('radio', { name: PALETTE_LABELS[palette] })).toBeInTheDocument()
    }
    expect(screen.getByRole('radio', { name: 'Kahve' })).toBeChecked()
  })

  it('selects a palette on click and reports it', async () => {
    const onChange = vi.fn()
    render(<ControlledPicker onChange={onChange} />)
    await userEvent.click(screen.getByRole('radio', { name: 'Çilek' }))
    expect(onChange).toHaveBeenCalledWith('strawberry')
    expect(screen.getByRole('radio', { name: 'Çilek' })).toBeChecked()
    expect(screen.getByRole('radio', { name: 'Kahve' })).not.toBeChecked()
  })

  it('supports arrow-key navigation like a native radio group', async () => {
    const onChange = vi.fn()
    render(<ControlledPicker onChange={onChange} />)
    await userEvent.click(screen.getByRole('radio', { name: 'Kahve' }))
    await userEvent.keyboard('{ArrowRight}')
    expect(onChange).toHaveBeenLastCalledWith('mono')
    expect(screen.getByRole('radio', { name: 'Tek renk' })).toHaveFocus()
  })

  it('accepts a custom legend', () => {
    render(<PalettePicker value="matcha" mode="light" onChange={vi.fn()} legend="Temanı seç" />)
    expect(screen.getByRole('group', { name: 'Temanı seç' })).toBeInTheDocument()
  })
})

describe('PalettePreview', () => {
  it('scopes the palette and mode on a decorative box', () => {
    const { container } = render(<PalettePreview palette="blueberry" mode="light" />)
    const box = container.firstElementChild
    expect(box).toHaveAttribute('data-palette', 'blueberry')
    expect(box).toHaveAttribute('data-theme', 'light')
    expect(box).toHaveAttribute('aria-hidden', 'true')
  })
})
