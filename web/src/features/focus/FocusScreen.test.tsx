import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices, type Repositories } from '@/data'
import { LONG_BREAK_THRESHOLD_MS } from '@/domain/calc/focus'
import { createTestServices, type TestServices } from '@/test/services'
import { FocusScreen } from './FocusScreen'

const MINUTE = 60_000
/** Gün ortası: testler gece yarısına taşmasın. */
const START = new Date('2026-11-18T10:00:00')

function renderScreen(services: AppServices) {
  render(
    <ServicesProvider services={services}>
      <FocusScreen />
    </ServicesProvider>,
  )
  return userEvent.setup()
}

/** Saati ileri sarar ve bir sayaç tikini çalıştırır (aradaki her saniyeyi tek tek tetiklemeden). */
async function advance(ms: number) {
  vi.setSystemTime(Date.now() + ms)
  await act(async () => {
    vi.advanceTimersByTime(1000)
  })
}

const focusTimer = () => screen.getByRole('timer', { name: 'Oturum süresi' })
const breakTimer = () => screen.getByRole('timer', { name: 'Mola süresi' })
const status = () => screen.getByRole('status')

async function seedSubjects(repos: Repositories) {
  const turkce = await repos.subjects.create({
    name: 'Türkçe',
    exam: 'TYT',
    fields: ['SAY', 'EA', 'SOZ', 'DIL'],
    catalogKey: null,
    order: 0,
  })
  const fizik = await repos.subjects.create({
    name: 'Fizik',
    exam: 'AYT',
    fields: ['SAY'],
    catalogKey: null,
    order: 1,
  })
  await repos.subjects.create({
    name: 'Tarih-1',
    exam: 'AYT',
    fields: ['EA', 'SOZ'],
    catalogKey: null,
    order: 2,
  })
  const topic = await repos.topics.create({
    subjectId: fizik.id,
    name: 'Kuvvet ve Hareket',
    catalogKey: null,
    order: 0,
  })
  return { turkce, fizik, topic }
}

describe('FocusScreen', () => {
  let ctx: TestServices
  let services: AppServices
  let repos: Repositories

  beforeEach(() => {
    vi.useFakeTimers({
      toFake: ['Date', 'setInterval', 'clearInterval'],
      shouldAdvanceTime: true,
      now: START,
    })
    ctx = createTestServices()
    services = ctx.services
    repos = services.repositories
  })

  afterEach(async () => {
    vi.useRealTimers()
    await ctx.dispose()
  })

  it('runs start → break → resume → finish and shows the summary and history', async () => {
    const user = renderScreen(services)

    expect(screen.getByRole('heading', { level: 1, name: 'Odak' })).toBeInTheDocument()
    expect(await screen.findByText('Henüz tamamlanmış oturum yok')).toBeInTheDocument()
    expect(screen.queryByRole('timer')).not.toBeInTheDocument()

    await user.click(await screen.findByRole('button', { name: 'Odak başlat' }))
    expect(await screen.findByRole('timer', { name: 'Oturum süresi' })).toHaveTextContent(
      /^00:0\d$/,
    )
    expect(status()).toHaveTextContent('Odak başladı')

    await advance(25 * MINUTE)
    expect(focusTimer()).toHaveTextContent(/^25:0\d$/)
    expect(screen.getByTestId('today-total')).toHaveTextContent('25 dk')

    await user.click(screen.getByRole('button', { name: 'Mola ver' }))
    expect(await screen.findByRole('timer', { name: 'Mola süresi' })).toBeInTheDocument()
    expect(screen.getByText('Mola')).toBeInTheDocument()
    expect(status()).toHaveTextContent('Mola başladı')

    await advance(5 * MINUTE)
    expect(breakTimer()).toHaveTextContent(/^05:0\d$/)
    expect(screen.getByTestId('today-total')).toHaveTextContent('25 dk')
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Devam et' }))
    expect(await screen.findByRole('timer', { name: 'Oturum süresi' })).toHaveTextContent(
      /^25:0\d$/,
    )
    expect(status()).toHaveTextContent('Odağa devam edildi')

    await advance(10 * MINUTE)
    await user.click(screen.getByRole('button', { name: 'Bitir' }))

    const summary = await screen.findByRole('dialog', { name: 'Oturum özeti' })
    const row = (title: string) =>
      within(summary)
        .getAllByRole('listitem')
        .find((item) => item.textContent?.includes(title))
    expect(row('Toplam odak')).toHaveTextContent('35 dk')
    expect(row('Mola sayısı')).toHaveTextContent('1')
    expect(row('Toplam mola')).toHaveTextContent('5 dk')
    expect(status()).toHaveTextContent('Oturum bitti')

    await user.click(within(summary).getByRole('button', { name: 'Tamam' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())

    const start = await screen.findByRole('button', { name: 'Odak başlat' })
    expect(start).toHaveFocus()
    const history = screen.getByRole('region', { name: 'Geçmiş oturumlar' })
    await waitFor(() => expect(within(history).getAllByRole('listitem')).toHaveLength(1))
    expect(within(history).getByRole('listitem')).toHaveTextContent(/Ders seçilmedi.*35 dk/)

    expect(screen.getByRole('region', { name: 'Ortalama kesintisiz odak' })).toHaveTextContent(
      '17 dk',
    )
    expect(screen.getByRole('region', { name: 'Ortalama mola' })).toHaveTextContent('5 dk')
    expect(screen.getByRole('region', { name: 'Bugün toplam' })).toHaveTextContent('35 dk')
    const week = screen.getByRole('list', { name: 'Son 7 gün' })
    const days = within(week).getAllByRole('listitem')
    expect(days).toHaveLength(7)
    expect(days.at(-1)).toHaveTextContent('Çar 18 Kas: 35 dk')
    expect(days.at(0)).toHaveTextContent('Per 12 Kas: 0 sn')
  })

  it('shows the long-break alert without auto-finishing, and "Oturumu bitir" finishes', async () => {
    const user = renderScreen(services)
    await user.click(await screen.findByRole('button', { name: 'Odak başlat' }))
    await advance(20 * MINUTE)
    await user.click(await screen.findByRole('button', { name: 'Mola ver' }))
    await screen.findByRole('timer', { name: 'Mola süresi' })

    await advance(LONG_BREAK_THRESHOLD_MS - 2 * MINUTE)
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()

    await advance(3 * MINUTE)
    const alert = screen.getByRole('alert')
    expect(within(alert).getByRole('heading', { name: 'Molan uzadı' })).toBeInTheDocument()
    expect(breakTimer()).toHaveTextContent(/^31:0\d$/)
    expect(await repos.focusSessions.findActive()).toBeDefined()

    await user.click(within(alert).getByRole('button', { name: 'Oturumu bitir' }))
    const summary = await screen.findByRole('dialog', { name: 'Oturum özeti' })
    expect(within(summary).getAllByRole('listitem')[0]).toHaveTextContent('20 dk')
    expect(await repos.focusSessions.findActive()).toBeUndefined()
  })

  it('"Devam et" in the long-break alert resumes focus', async () => {
    const user = renderScreen(services)
    await user.click(await screen.findByRole('button', { name: 'Odak başlat' }))
    await user.click(await screen.findByRole('button', { name: 'Mola ver' }))
    await screen.findByRole('timer', { name: 'Mola süresi' })
    await advance(LONG_BREAK_THRESHOLD_MS)

    await user.click(within(screen.getByRole('alert')).getByRole('button', { name: 'Devam et' }))
    expect(await screen.findByRole('timer', { name: 'Oturum süresi' })).toBeInTheDocument()
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('resumes an active session from the database after a reload', async () => {
    const startedAt = new Date(Date.now() - 10 * MINUTE).toISOString()
    const session = await repos.focusSessions.create({
      subjectId: null,
      topicId: null,
      startedAt,
      endedAt: null,
      note: null,
    })
    await repos.focusSegments.create({
      sessionId: session.id,
      kind: 'focus',
      startedAt,
      endedAt: null,
    })

    renderScreen(services)

    const timer = await screen.findByRole('timer', { name: 'Oturum süresi' })
    expect(timer.textContent).toMatch(/^1\d:\d\d$/)
    expect(screen.getByTestId('today-total')).toHaveTextContent('10 dk')
    expect(screen.getByRole('button', { name: 'Mola ver' })).toBeInTheDocument()
  })

  it('filters subjects by profile field, enables topics after a subject and records both', async () => {
    const { fizik, topic } = await seedSubjects(repos)
    await repos.profiles.create({
      displayName: null,
      field: 'SAY',
      appleUserId: null,
      targetExamYear: null,
      onboardingCompletedAt: START.toISOString(),
    })
    const user = renderScreen(services)

    const subjectSelect = await screen.findByLabelText('Ders (isteğe bağlı)')
    const topicSelect = screen.getByLabelText('Konu (isteğe bağlı)')
    await waitFor(() =>
      expect(
        within(subjectSelect)
          .getAllByRole('option')
          .map((o) => o.textContent),
      ).toEqual(['Ders seçilmedi', 'Türkçe', 'Fizik']),
    )
    expect(topicSelect).toBeDisabled()

    await user.selectOptions(subjectSelect, 'Fizik')
    await waitFor(() => expect(topicSelect).toBeEnabled())
    await user.selectOptions(topicSelect, await screen.findByRole('option', { name: topic.name }))
    await user.click(screen.getByRole('button', { name: 'Odak başlat' }))

    expect(await screen.findByText('AYT · Fizik · Kuvvet ve Hareket')).toBeInTheDocument()
    expect(await repos.focusSessions.findActive()).toMatchObject({
      subjectId: fizik.id,
      topicId: topic.id,
    })

    await advance(MINUTE)
    await user.click(screen.getByRole('button', { name: 'Bitir' }))
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', { name: 'Tamam' }),
    )
    const history = screen.getByRole('region', { name: 'Geçmiş oturumlar' })
    await waitFor(() =>
      expect(within(history).getByRole('listitem')).toHaveTextContent(
        /Fizik.*AYT · Kuvvet ve Hareket.*1 dk/,
      ),
    )
  })

  it('choosing "Ders seçilmedi" again clears the topic', async () => {
    const { fizik, topic } = await seedSubjects(repos)
    const user = renderScreen(services)
    const subjectSelect = await screen.findByLabelText('Ders (isteğe bağlı)')
    await screen.findByRole('option', { name: 'Tarih-1' })

    await user.selectOptions(subjectSelect, fizik.id)
    const topicSelect = screen.getByLabelText('Konu (isteğe bağlı)')
    await user.selectOptions(topicSelect, await screen.findByRole('option', { name: topic.name }))
    await user.selectOptions(subjectSelect, '')

    expect(topicSelect).toBeDisabled()
    expect(topicSelect).toHaveValue('')
  })

  it('shows an error and stays idle when saving fails', async () => {
    vi.spyOn(repos.focusSessions, 'create').mockRejectedValue(new Error('disk dolu'))
    const user = renderScreen(services)

    await user.click(await screen.findByRole('button', { name: 'Odak başlat' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('İşlem kaydedilemedi')
    expect(screen.queryByRole('timer')).not.toBeInTheDocument()
    expect(status()).toBeEmptyDOMElement()
  })
})
