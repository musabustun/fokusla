import { render, screen, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices, type Repositories } from '@/data'
import { toISODate, toISODateTime } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { FocusCard } from './FocusCard'

/** Gün ortası (Çarşamba 18 Kasım): testler gece yarısına taşmasın. */
const NOW = new Date('2026-11-18T10:00:00')
const TODAY = toISODate(NOW)

function at(time: string): string {
  return toISODateTime(new Date(`2026-11-18T${time}`))
}

function renderCard(services: AppServices) {
  const router = createMemoryRouter(
    [
      { path: ROUTES.today, element: <FocusCard today={TODAY} /> },
      { path: ROUTES.focus, element: <h1>Odak ekranı</h1> },
    ],
    { initialEntries: [ROUTES.today] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
}

/** 09:00–09:30 kapalı oturum: 25 dk odak + 5 dk mola. */
async function seedClosedSession(repos: Repositories) {
  const session = await repos.focusSessions.create({
    subjectId: null,
    topicId: null,
    startedAt: at('09:00:00'),
    endedAt: at('09:30:00'),
    note: null,
  })
  await repos.focusSegments.create({
    sessionId: session.id,
    kind: 'focus',
    startedAt: at('09:00:00'),
    endedAt: at('09:25:00'),
  })
  await repos.focusSegments.create({
    sessionId: session.id,
    kind: 'break',
    startedAt: at('09:25:00'),
    endedAt: at('09:30:00'),
  })
}

/** 09:40'ta başlamış, hâlâ açık odak segmenti olan oturum (NOW'da 20 dk). */
async function seedOpenSession(repos: Repositories, kind: 'focus' | 'break' = 'focus') {
  const session = await repos.focusSessions.create({
    subjectId: null,
    topicId: null,
    startedAt: at('09:40:00'),
    endedAt: null,
    note: null,
  })
  if (kind === 'focus') {
    await repos.focusSegments.create({
      sessionId: session.id,
      kind: 'focus',
      startedAt: at('09:40:00'),
      endedAt: null,
    })
    return
  }
  await repos.focusSegments.create({
    sessionId: session.id,
    kind: 'focus',
    startedAt: at('09:40:00'),
    endedAt: at('09:55:00'),
  })
  await repos.focusSegments.create({
    sessionId: session.id,
    kind: 'break',
    startedAt: at('09:55:00'),
    endedAt: null,
  })
}

const card = () => screen.getByRole('region', { name: 'Odak' })
const summaryList = () => screen.getByRole('list', { name: 'Bugünün odak özeti' })

describe('FocusCard', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    vi.useFakeTimers({
      toFake: ['Date', 'setInterval', 'clearInterval'],
      shouldAdvanceTime: true,
      now: NOW,
    })
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    vi.useRealTimers()
    await ctx.dispose()
  })

  it('shows the empty state with a single "Odak başlat" link to /odak', async () => {
    renderCard(services)

    const start = await screen.findByRole('link', { name: 'Odak başlat' })
    expect(start).toHaveAttribute('href', ROUTES.focus)
    expect(screen.getByText('Bugün henüz odaklanmadın — 25 dakikayla başla.')).toBeInTheDocument()
    expect(screen.queryByRole('timer')).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Devam et' })).not.toBeInTheDocument()
    expect(screen.getByTestId('today-focus-total')).toHaveTextContent('0 dk')
    expect(within(summaryList()).getByText('Ortalama kesintisiz odak: henüz yok')).toBeVisible()
    expect(within(card()).getByRole('link', { name: 'Tümü: Odak ekranı' })).toHaveAttribute(
      'href',
      ROUTES.focus,
    )
  })

  it("shows today's total, session count and average for a closed session", async () => {
    await seedClosedSession(services.repositories)
    renderCard(services)

    expect(await screen.findByText('Bugün toplam: 25 dk')).toBeInTheDocument()
    const summary = summaryList()
    expect(within(summary).getByText('Oturum sayısı: 1')).toBeInTheDocument()
    expect(within(summary).getByText('Ortalama kesintisiz odak: 25 dk')).toBeInTheDocument()
    expect(screen.getByTestId('today-focus-total')).toHaveTextContent('25 dk')
    expect(screen.getByRole('link', { name: 'Odak başlat' })).toHaveAttribute('href', ROUTES.focus)
    expect(screen.queryByText(/Bugün henüz odaklanmadın/)).not.toBeInTheDocument()
  })

  it('shows the live session timer and "Devam et" for an open session', async () => {
    await seedOpenSession(services.repositories)
    renderCard(services)

    const timer = await screen.findByRole('timer', { name: 'Oturum süresi' })
    expect(timer).toHaveTextContent(/^20:0\d$/)
    expect(screen.getByText('Odaktasın')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Devam et' })).toHaveAttribute('href', ROUTES.focus)
    expect(screen.queryByRole('link', { name: 'Odak başlat' })).not.toBeInTheDocument()
    expect(screen.queryByText(/Bugün henüz odaklanmadın/)).not.toBeInTheDocument()
    expect(within(summaryList()).getByText('Oturum sayısı: 1')).toBeInTheDocument()
    // Açık segment henüz kapanmadığı için ortalamaya girmez.
    expect(within(summaryList()).getByText('Ortalama kesintisiz odak: henüz yok')).toBeVisible()
  })

  it('shows "Moladasın" with the paused session focus time during a break', async () => {
    await seedOpenSession(services.repositories, 'break')
    renderCard(services)

    expect(await screen.findByRole('timer', { name: 'Oturum süresi' })).toHaveTextContent('15:00')
    expect(screen.getByText('Moladasın')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Devam et' })).toBeInTheDocument()
  })

  it('renders a 7-day chart ending today', async () => {
    await seedClosedSession(services.repositories)
    renderCard(services)
    await screen.findByText('Bugün toplam: 25 dk')

    const days = within(screen.getByRole('list', { name: 'Son 7 gün' })).getAllByRole('listitem')
    expect(days).toHaveLength(7)
    expect(days.at(-1)).toHaveAttribute('aria-current', 'date')
    expect(days.at(-1)).toHaveTextContent('Çarşamba: 25 dk')
    expect(days.at(0)).toHaveTextContent('Perşembe: 0 dk')
    expect(days.filter((day) => day.hasAttribute('aria-current'))).toHaveLength(1)
  })
})
