import { render, screen, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider } from '@/data'
import { createTestServices, type TestServices } from '@/test/services'
import { TodayScreen } from './TodayScreen'

function renderToday(ctx: TestServices) {
  const router = createMemoryRouter([{ path: ROUTES.today, Component: TodayScreen }], {
    initialEntries: [ROUTES.today],
  })
  render(
    <ServicesProvider services={ctx.services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
}

describe('TodayScreen', () => {
  let ctx: TestServices

  beforeEach(() => {
    // Yalnızca Date sahte: Dexie'nin zamanlayıcıları gerçek kalsın.
    vi.useFakeTimers({ now: new Date(2026, 10, 19, 19, 30), toFake: ['Date'] })
    ctx = createTestServices()
  })

  afterEach(async () => {
    vi.useRealTimers()
    await ctx.dispose()
  })

  it('shows date, greeting with name and the YKS field', async () => {
    await ctx.services.repositories.profiles.create({
      displayName: 'Deniz',
      field: 'EA',
      appleUserId: null,
      targetExamYear: 2027,
      onboardingCompletedAt: '2026-11-01T08:00:00.000Z',
    })
    renderToday(ctx)

    expect(screen.getByRole('heading', { level: 1, name: 'Bugün' })).toBeInTheDocument()
    expect(screen.getByText('19 Kasım Perşembe')).toBeInTheDocument()
    expect(await screen.findByText('İyi akşamlar, Deniz')).toBeInTheDocument()
    expect(screen.getByText('Eşit Ağırlık')).toBeInTheDocument()
  })

  it('greets without a name before the profile exists', () => {
    renderToday(ctx)
    expect(screen.getByText('İyi akşamlar')).toBeInTheDocument()
  })

  it('renders the cards with Focus first and each empty state pointing to one next step', async () => {
    renderToday(ctx)

    const regions = await screen.findAllByRole('region')
    expect(regions[0]).toHaveAccessibleName('Odak')
    const tasks = await screen.findByRole('region', { name: 'Bugünün görevleri' })
    expect(await within(tasks).findByRole('link', { name: 'Görev ekle' })).toHaveAttribute(
      'href',
      ROUTES.tasks,
    )
    const tests = screen.getByRole('region', { name: 'Son testler' })
    expect(await within(tests).findByRole('link', { name: 'İlk testini ekle' })).toHaveAttribute(
      'href',
      ROUTES.analysis,
    )
    const books = screen.getByRole('region', { name: 'Kitaplar' })
    expect(await within(books).findByRole('link', { name: 'Kitap ekle' })).toHaveAttribute(
      'href',
      ROUTES.books,
    )
  })
})
