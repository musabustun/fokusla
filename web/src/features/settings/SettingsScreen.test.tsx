import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import { createTestServices, type TestServices } from '@/test/services'
import { ThemeProvider } from '@/ui'
import { SettingsScreen } from './SettingsScreen'
import { downloadJson } from './downloadJson'

vi.mock('./downloadJson', () => ({ downloadJson: vi.fn() }))

let ctx: TestServices
let services: AppServices

function renderSettings() {
  render(
    <ServicesProvider services={services}>
      <ThemeProvider>
        <SettingsScreen />
      </ThemeProvider>
    </ServicesProvider>,
  )
  return userEvent.setup()
}

async function seedProfile(overrides: { displayName?: string | null; field?: 'SAY' | 'SOZ' } = {}) {
  return services.repositories.profiles.create({
    displayName: overrides.displayName ?? null,
    field: overrides.field ?? 'SAY',
    appleUserId: null,
    targetExamYear: null,
    onboardingCompletedAt: '2026-11-19T08:00:00.000Z',
  })
}

async function seedBook() {
  return services.repositories.books.create({
    title: 'Soru Bankası',
    publisher: null,
    kind: 'questionBank',
    subjectId: null,
    exam: null,
    unit: 'page',
    totalUnits: 200,
    archivedAt: null,
  })
}

beforeEach(() => {
  window.localStorage.clear()
  delete document.documentElement.dataset.palette
  delete document.documentElement.dataset.theme
  vi.mocked(downloadJson).mockClear()
  ctx = createTestServices()
  services = ctx.services
})

afterEach(async () => {
  await ctx.dispose()
})

describe('SettingsScreen · görünüm', () => {
  it('switches the mode from the Görünüm section', async () => {
    const user = renderSettings()
    expect(screen.getByRole('heading', { level: 1, name: 'Ayarlar' })).toBeInTheDocument()
    const mode = screen.getByRole('radiogroup', { name: 'Mod' })
    await user.click(within(mode).getByRole('radio', { name: 'Koyu' }))
    expect(within(mode).getByRole('radio', { name: 'Koyu' })).toBeChecked()
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    await user.click(within(mode).getByRole('radio', { name: 'Açık' }))
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
  })

  it('lists all six palettes with Kahve selected by default', () => {
    renderSettings()
    const group = screen.getByRole('group', { name: 'Renk teması' })
    for (const label of ['Kahve', 'Tek renk', 'Çilek', 'Matcha', 'Yaban mersini', 'Limonata']) {
      expect(within(group).getByRole('radio', { name: label })).toBeInTheDocument()
    }
    expect(within(group).getAllByRole('radio')).toHaveLength(6)
    expect(within(group).getByRole('radio', { name: 'Kahve' })).toBeChecked()
  })

  it('applies and persists the chosen palette immediately', async () => {
    const user = renderSettings()
    await user.click(screen.getByRole('radio', { name: 'Matcha' }))
    expect(screen.getByRole('radio', { name: 'Matcha' })).toBeChecked()
    expect(document.documentElement.dataset.palette).toBe('matcha')
    expect(window.localStorage.getItem('fokus.palette')).toBe('matcha')
    await user.click(screen.getByRole('radio', { name: 'Kahve' }))
    expect(document.documentElement.dataset.palette).toBe('coffee')
  })
})

describe('SettingsScreen · profil', () => {
  it('changes the YKS field without deleting any data', async () => {
    await seedProfile({ field: 'SAY' })
    await seedBook()
    const user = renderSettings()

    await user.click(await screen.findByRole('button', { name: /YKS alanı/ }))
    const dialog = await screen.findByRole('dialog', { name: 'YKS alanı' })
    expect(within(dialog).getByRole('radio', { name: /Sayısal/ })).toBeChecked()
    await user.click(within(dialog).getByRole('radio', { name: /Sözel/ }))

    await waitFor(async () =>
      expect((await services.repositories.profiles.getCurrent())?.field).toBe('SOZ'),
    )
    expect(await screen.findByRole('button', { name: /YKS alanı.*Sözel/ })).toBeInTheDocument()
    expect(await services.repositories.books.findAll()).toHaveLength(1)
  })

  it('saves, trims and clears the display name', async () => {
    await seedProfile()
    const user = renderSettings()

    await user.click(await screen.findByRole('button', { name: /Görünen ad.*Eklenmedi/ }))
    await user.type(await screen.findByRole('textbox', { name: 'Ad' }), '  Ayşe  ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(async () =>
      expect((await services.repositories.profiles.getCurrent())?.displayName).toBe('Ayşe'),
    )
    expect(await screen.findByRole('button', { name: /Görünen ad.*Ayşe/ })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /Görünen ad/ }))
    await user.clear(await screen.findByRole('textbox', { name: 'Ad' }))
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(async () =>
      expect((await services.repositories.profiles.getCurrent())?.displayName).toBeNull(),
    )
  })
})

describe('SettingsScreen · hesap ve senkron', () => {
  it('explains why sync is off while signed out and keeps the switch disabled', async () => {
    await seedProfile()
    renderSettings()

    expect(await screen.findByRole('button', { name: /Apple ile Giriş/ })).toBeInTheDocument()
    expect(screen.getByRole('switch', { name: 'iCloud senkronu' })).toBeDisabled()
    expect(screen.getByText(/giriş yapmadın/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Çıkış yap' })).not.toBeInTheDocument()
  })

  it('signs in with the mock Apple account and links it to the profile', async () => {
    await seedProfile()
    const user = renderSettings()

    await user.click(await screen.findByRole('button', { name: /Apple ile Giriş/ }))

    expect(await screen.findByRole('button', { name: 'Çıkış yap' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Hesabı sil' })).toBeInTheDocument()
    expect((await services.auth.getSession())?.isMock).toBe(true)
    const profile = await services.repositories.profiles.getCurrent()
    expect(profile?.appleUserId).toMatch(/^mock-apple-/)
    expect(screen.getByRole('switch', { name: 'iCloud senkronu' })).toBeEnabled()
  })

  it('turns sync on and off once signed in', async () => {
    await seedProfile()
    const user = renderSettings()
    await user.click(await screen.findByRole('button', { name: /Apple ile Giriş/ }))
    const toggle = await screen.findByRole('switch', { name: 'iCloud senkronu' })
    await waitFor(() => expect(toggle).toBeEnabled())

    await user.click(toggle)
    expect(toggle).toBeChecked()
    expect(await screen.findByText(/Son senkron:/)).toBeInTheDocument()
    expect(services.sync.getState().kind).toBe('idle')

    await user.click(toggle)
    expect(toggle).not.toBeChecked()
    expect(services.sync.getState().kind).toBe('disabled')
    expect(screen.getByText('Kapalı')).toBeInTheDocument()
  })

  it('signs out, disables sync and keeps local data', async () => {
    await seedProfile()
    await seedBook()
    const user = renderSettings()
    await user.click(await screen.findByRole('button', { name: /Apple ile Giriş/ }))
    await user.click(await screen.findByRole('switch', { name: 'iCloud senkronu' }))

    await user.click(await screen.findByRole('button', { name: 'Çıkış yap' }))

    expect(await screen.findByRole('button', { name: /Apple ile Giriş/ })).toBeInTheDocument()
    expect(await services.auth.getSession()).toBeNull()
    expect(services.sync.getState().kind).toBe('disabled')
    expect((await services.repositories.profiles.getCurrent())?.appleUserId).toBeNull()
    expect(await services.repositories.books.findAll()).toHaveLength(1)
    expect(screen.getByRole('switch', { name: 'iCloud senkronu' })).toBeDisabled()
  })
})

describe('SettingsScreen · hesabı sil', () => {
  async function openDeleteAccount() {
    await seedProfile()
    await seedBook()
    const user = renderSettings()
    await user.click(await screen.findByRole('button', { name: /Apple ile Giriş/ }))
    await user.click(await screen.findByRole('button', { name: 'Hesabı sil' }))
    const dialog = await screen.findByRole('dialog', { name: 'Hesabı sil' })
    return { user, dialog }
  }

  it('can be cancelled without side effects', async () => {
    const { user, dialog } = await openDeleteAccount()
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }))
    expect(await services.auth.getSession()).not.toBeNull()
  })

  it('deletes the account and then asks separately about local data (keep)', async () => {
    const { user, dialog } = await openDeleteAccount()
    await user.click(within(dialog).getByRole('button', { name: 'Hesabımı sil' }))

    const question = await screen.findByRole('dialog', { name: 'Cihazdaki verilerin ne olsun?' })
    expect(await services.auth.getSession()).toBeNull()
    expect(services.sync.getState().kind).toBe('disabled')
    await user.click(within(question).getByRole('button', { name: 'Verilerimi cihazda tut' }))

    expect(await services.repositories.books.findAll()).toHaveLength(1)
    expect((await services.repositories.profiles.getCurrent())?.appleUserId).toBeNull()
    expect(await screen.findByRole('button', { name: /Apple ile Giriş/ })).toBeInTheDocument()
  })

  it('can continue to the double-confirmed local data wipe', async () => {
    const { user, dialog } = await openDeleteAccount()
    await user.click(within(dialog).getByRole('button', { name: 'Hesabımı sil' }))
    const question = await screen.findByRole('dialog', { name: 'Cihazdaki verilerin ne olsun?' })
    await user.click(within(question).getByRole('button', { name: /Cihazdaki verileri de sil/ }))

    const warn = await screen.findByRole('dialog', { name: 'Tüm veriler silinsin mi?' })
    expect(await services.repositories.books.findAll()).toHaveLength(1)
    await user.click(within(warn).getByRole('button', { name: 'Devam' }))
    const final = await screen.findByRole('dialog', { name: 'Emin misin?' })
    await user.click(within(final).getByRole('button', { name: 'Her şeyi kalıcı olarak sil' }))

    await waitFor(async () => expect(await services.repositories.books.findAll()).toHaveLength(0))
  })
})

describe('SettingsScreen · veri', () => {
  it('exports all live data as a JSON download', async () => {
    await seedProfile({ displayName: 'Ayşe' })
    const book = await seedBook()
    const user = renderSettings()

    await user.click(await screen.findByRole('button', { name: /Verileri dışa aktar/ }))

    await waitFor(() => expect(downloadJson).toHaveBeenCalledTimes(1))
    const [filename, backup] = vi.mocked(downloadJson).mock.calls[0] ?? []
    expect(filename).toMatch(/^fokus-yedek-\d{4}-\d{2}-\d{2}\.json$/)
    expect(backup).toMatchObject({
      app: 'fokus',
      formatVersion: 1,
      entities: { books: [{ id: book.id }], profiles: [{ displayName: 'Ayşe' }] },
    })
    expect(await screen.findByText(/Yedek indirildi/)).toBeInTheDocument()
  })

  it('wipes everything only after two confirmations', async () => {
    await seedProfile()
    await seedBook()
    const user = renderSettings()

    await user.click(await screen.findByRole('button', { name: 'Tüm verileri sil' }))
    const warn = await screen.findByRole('dialog', { name: 'Tüm veriler silinsin mi?' })
    // Vazgeç hiçbir şeyi silmez.
    await user.click(within(warn).getByRole('button', { name: 'Vazgeç' }))
    expect(await services.repositories.books.findAll()).toHaveLength(1)

    await user.click(screen.getByRole('button', { name: 'Tüm verileri sil' }))
    await user.click(
      within(await screen.findByRole('dialog', { name: 'Tüm veriler silinsin mi?' })).getByRole(
        'button',
        { name: 'Devam' },
      ),
    )
    // İlk onaydan sonra hâlâ hiçbir şey silinmedi.
    expect(await services.repositories.books.findAll()).toHaveLength(1)
    const final = await screen.findByRole('dialog', { name: 'Emin misin?' })
    await user.click(within(final).getByRole('button', { name: 'Her şeyi kalıcı olarak sil' }))

    await waitFor(async () => expect(await services.repositories.books.findAll()).toHaveLength(0))
    expect(await services.repositories.profiles.getCurrent()).toBeUndefined()
    // Müfredat kataloğu yeniden tohumlanır; ders/konu seçimi boş kalmaz.
    await waitFor(async () =>
      expect((await services.repositories.subjects.findAll()).length).toBeGreaterThan(0),
    )
  })
})

describe('SettingsScreen · hakkında', () => {
  it('links to the repository and states the privacy summary', async () => {
    renderSettings()
    const link = screen.getByRole('link', { name: /Açık kaynak — GitHub/ })
    expect(link).toHaveAttribute('href', 'https://github.com/musabustun/fokusla')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'))
    expect(
      screen.getByText('Verilerin cihazında kalır; yalnızca iCloud hesabınla senkronize olur.'),
    ).toBeInTheDocument()
    expect(screen.getByText('0.1.0')).toBeInTheDocument()
  })
})
