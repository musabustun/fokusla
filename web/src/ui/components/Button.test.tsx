import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { Button } from './Button'

describe('Button', () => {
  it('renders a type="button" by default and handles clicks', async () => {
    const onClick = vi.fn()
    render(<Button onClick={onClick}>Başlat</Button>)
    const button = screen.getByRole('button', { name: 'Başlat' })
    expect(button).toHaveAttribute('type', 'button')
    await userEvent.click(button)
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('does not fire clicks when disabled', async () => {
    const onClick = vi.fn()
    render(
      <Button disabled onClick={onClick}>
        Kaydet
      </Button>,
    )
    await userEvent.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(onClick).not.toHaveBeenCalled()
  })

  it('is disabled and aria-busy while loading', async () => {
    const onClick = vi.fn()
    render(
      <Button loading onClick={onClick}>
        Kaydediliyor
      </Button>,
    )
    const button = screen.getByRole('button', { name: 'Kaydediliyor' })
    expect(button).toBeDisabled()
    expect(button).toHaveAttribute('aria-busy', 'true')
    await userEvent.click(button)
    expect(onClick).not.toHaveBeenCalled()
  })

  it('allows submit buttons', () => {
    render(<Button type="submit">Gönder</Button>)
    expect(screen.getByRole('button', { name: 'Gönder' })).toHaveAttribute('type', 'submit')
  })
})
