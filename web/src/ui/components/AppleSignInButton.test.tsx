import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { AppleSignInButton } from './AppleSignInButton'

describe('AppleSignInButton', () => {
  it('tıklanınca onClick çağırır', async () => {
    const onClick = vi.fn()
    render(<AppleSignInButton onClick={onClick} />)
    await userEvent.click(screen.getByRole('button', { name: 'Apple ile Giriş' }))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('yüklenirken devre dışıdır ve meşgul olduğunu bildirir', () => {
    render(<AppleSignInButton onClick={vi.fn()} loading />)
    const button = screen.getByRole('button', { name: 'Giriş yapılıyor…' })
    expect(button).toBeDisabled()
    expect(button).toHaveAttribute('aria-busy', 'true')
  })

  it('özel etiket ve devre dışı durumunu destekler', () => {
    render(<AppleSignInButton onClick={vi.fn()} disabled label="Apple ile devam et" />)
    expect(screen.getByRole('button', { name: 'Apple ile devam et' })).toBeDisabled()
  })
})
