import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ThemeProvider } from './ThemeProvider'
import {
  PALETTE_STORAGE_KEY,
  readStoredPalette,
  readStoredPreference,
  THEME_STORAGE_KEY,
} from './themeStorage'
import { useThemeStore } from './themeStore'
import { useTheme } from './useTheme'

function ThemeProbe() {
  const { preference, resolved, setPreference, palette, setPalette } = useTheme()
  return (
    <div>
      <p>
        {preference}/{resolved}
      </p>
      <p>palet: {palette}</p>
      <button type="button" onClick={() => setPreference('dark')}>
        Koyu
      </button>
      <button type="button" onClick={() => setPalette('matcha')}>
        Matcha
      </button>
    </div>
  )
}

type ChangeListener = (event: MediaQueryListEvent) => void

function mockMatchMedia(initialDark: boolean) {
  const listeners = new Set<ChangeListener>()
  const query = {
    matches: initialDark,
    addEventListener: (_: string, listener: ChangeListener) => listeners.add(listener),
    removeEventListener: (_: string, listener: ChangeListener) => listeners.delete(listener),
  }
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => query),
  )
  return (matches: boolean) =>
    listeners.forEach((listener) => listener({ matches } as MediaQueryListEvent))
}

beforeEach(() => {
  window.localStorage.clear()
  useThemeStore.setState({ preference: 'system', palette: 'coffee', systemDark: false })
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
  delete document.documentElement.dataset.theme
  delete document.documentElement.dataset.palette
})

describe('theme', () => {
  it('applies the light theme when following a light system', () => {
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    expect(screen.getByText('system/light')).toBeInTheDocument()
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
    expect(document.documentElement.style.colorScheme).toBe('light')
  })

  it('keeps the theme-color meta in sync with the background token', async () => {
    const meta = document.createElement('meta')
    meta.name = 'theme-color'
    document.head.append(meta)
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    expect(meta).toHaveAttribute('content', '#F5F2EA')
    await userEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(meta).toHaveAttribute('content', '#0E0F0C')
    meta.remove()
  })

  it('persists an explicit preference and applies data-theme', async () => {
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    await userEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(window.localStorage.getItem(THEME_STORAGE_KEY)).toBe('dark')
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(screen.getByText('dark/dark')).toBeInTheDocument()
  })

  it('follows system theme changes while the preference is system', () => {
    const emitChange = mockMatchMedia(false)
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    act(() => emitChange(true))
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(screen.getByText('system/dark')).toBeInTheDocument()
  })

  it('follows the device (system) and the Kahve palette when nothing is stored', () => {
    expect(readStoredPreference()).toBe('system')
    expect(readStoredPalette()).toBe('coffee')
  })

  it('ignores invalid stored values and survives storage errors', () => {
    window.localStorage.setItem(THEME_STORAGE_KEY, 'neon')
    window.localStorage.setItem(PALETTE_STORAGE_KEY, 'grape')
    expect(readStoredPreference()).toBe('system')
    expect(readStoredPalette()).toBe('coffee')
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked')
    })
    expect(readStoredPreference()).toBe('system')
    expect(readStoredPalette()).toBe('coffee')
  })

  it('applies and persists the palette independently of the mode', async () => {
    const meta = document.createElement('meta')
    meta.name = 'theme-color'
    document.head.append(meta)
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    expect(document.documentElement).toHaveAttribute('data-palette', 'coffee')
    await userEvent.click(screen.getByRole('button', { name: 'Matcha' }))
    expect(document.documentElement).toHaveAttribute('data-palette', 'matcha')
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
    expect(window.localStorage.getItem(PALETTE_STORAGE_KEY)).toBe('matcha')
    expect(screen.getByText('palet: matcha')).toBeInTheDocument()
    expect(meta).toHaveAttribute('content', '#F1F4EA')
    await userEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(document.documentElement).toHaveAttribute('data-palette', 'matcha')
    expect(meta).toHaveAttribute('content', '#0C100B')
    meta.remove()
  })

  it('logs instead of throwing when storage writes fail', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('quota')
    })
    render(
      <ThemeProvider>
        <ThemeProbe />
      </ThemeProvider>,
    )
    await userEvent.click(screen.getByRole('button', { name: 'Matcha' }))
    expect(document.documentElement).toHaveAttribute('data-palette', 'matcha')
    expect(warn).toHaveBeenCalled()
  })
})
