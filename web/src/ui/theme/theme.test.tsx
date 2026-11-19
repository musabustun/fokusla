import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ThemeProvider } from './ThemeProvider'
import { readStoredPreference, THEME_STORAGE_KEY } from './themeStorage'
import { useThemeStore } from './themeStore'
import { useTheme } from './useTheme'

function ThemeProbe() {
  const { preference, resolved, setPreference } = useTheme()
  return (
    <div>
      <p>
        {preference}/{resolved}
      </p>
      <button type="button" onClick={() => setPreference('dark')}>
        Koyu
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
  useThemeStore.setState({ preference: 'system', systemDark: false })
})

afterEach(() => {
  vi.unstubAllGlobals()
  delete document.documentElement.dataset.theme
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

  it('defaults to the dark preference when nothing is stored', () => {
    expect(readStoredPreference()).toBe('dark')
  })

  it('ignores invalid stored values and survives storage errors', () => {
    window.localStorage.setItem(THEME_STORAGE_KEY, 'neon')
    expect(readStoredPreference()).toBe('dark')
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked')
    })
    expect(readStoredPreference()).toBe('dark')
  })
})
