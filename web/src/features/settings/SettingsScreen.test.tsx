import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'
import { ThemeProvider } from '@/ui'
import { SettingsScreen } from './SettingsScreen'

afterEach(() => {
  window.localStorage.clear()
})

describe('SettingsScreen', () => {
  it('switches the theme from the Görünüm section', async () => {
    render(
      <ThemeProvider>
        <SettingsScreen />
      </ThemeProvider>,
    )
    expect(screen.getByRole('heading', { level: 1, name: 'Ayarlar' })).toBeInTheDocument()
    await userEvent.click(screen.getByRole('radio', { name: 'Koyu' }))
    expect(screen.getByRole('radio', { name: 'Koyu' })).toBeChecked()
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(screen.getByText('Açık kaynak · MIT')).toBeInTheDocument()
  })
})
