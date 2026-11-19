import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type Repositories } from '@/data'
import type { ISODate, Task } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { TasksCard } from './TasksCard'

/** Perşembe, 19 Kasım 2026, 10:00 (yerel). */
const NOW = new Date(2026, 10, 19, 10, 0, 0)
const TODAY: ISODate = '2026-11-19'

function routine(repos: Repositories, title: string, order = 0): Promise<Task> {
  return repos.tasks.create({
    title,
    kind: 'routine',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: { frequency: 'daily', weekdays: [] },
    completedAt: null,
    order,
    startDate: TODAY,
  })
}

function assignment(repos: Repositories, title: string, dueDate: ISODate | null): Promise<Task> {
  return repos.tasks.create({
    title,
    kind: 'assignment',
    notes: null,
    subjectId: null,
    dueDate,
    recurrence: null,
    completedAt: null,
    order: 0,
  })
}

function card() {
  return screen.getByRole('region', { name: 'Bugünün görevleri' })
}

describe('TasksCard', () => {
  let ctx: TestServices
  let repos: Repositories

  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(NOW)
    ctx = createTestServices()
    repos = ctx.services.repositories
  })

  afterEach(async () => {
    vi.restoreAllMocks()
    vi.useRealTimers()
    await ctx.dispose()
  })

  function renderCard() {
    const router = createMemoryRouter(
      [
        { path: '/', element: <TasksCard today={TODAY} /> },
        { path: ROUTES.tasks, element: <p>Görevler ekranı</p> },
      ],
      { initialEntries: ['/'] },
    )
    return render(
      <ServicesProvider services={ctx.services}>
        <RouterProvider router={router} />
      </ServicesProvider>,
    )
  }

  it('görev yoksa boş durum ve görev ekleme bağlantısı gösterir', async () => {
    renderCard()

    expect(await screen.findByText('Bugün için görev yok.')).toBeInTheDocument()
    expect(within(card()).getByRole('link', { name: 'Görev ekle' })).toHaveAttribute(
      'href',
      ROUTES.tasks,
    )
    // Boş durumda tek sonraki adım gösterilir; "Tümü" bağlantısı yok.
    expect(within(card()).queryByRole('link', { name: 'Tüm görevler' })).not.toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('geciken, rutin, bugün teslim ve yaklaşan görevleri sayılarıyla listeler', async () => {
    await routine(repos, 'Paragraf çöz')
    await assignment(repos, 'Fizik ödevi', '2026-11-16')
    await assignment(repos, 'Kimya özeti', TODAY)
    await assignment(repos, 'Deneme analizi', null)
    await assignment(repos, 'Tarih ödevi', '2026-11-20')
    await assignment(repos, 'Biyoloji projesi', '2026-11-23')
    renderCard()

    expect(await screen.findByText('0 / 4 tamamlandı')).toBeInTheDocument()
    const checkboxes = within(card()).getAllByRole('checkbox')
    expect(checkboxes.map((box) => box.getAttribute('aria-label'))).toEqual([
      'Fizik ödevi',
      'Paragraf çöz',
      'Kimya özeti',
      'Deneme analizi',
      'Tarih ödevi',
      'Biyoloji projesi',
    ])
    expect(screen.getByRole('checkbox', { name: 'Fizik ödevi' })).toHaveAccessibleDescription(
      'Gecikti · 3 gün',
    )
    expect(screen.getByRole('checkbox', { name: 'Paragraf çöz' })).toHaveAccessibleDescription(
      'Rutin',
    )
    expect(screen.getByRole('checkbox', { name: 'Kimya özeti' })).toHaveAccessibleDescription(
      'Bugün teslim',
    )
    expect(screen.getByRole('checkbox', { name: 'Deneme analizi' })).toHaveAccessibleDescription(
      'Tarihsiz',
    )
    expect(screen.getByRole('checkbox', { name: 'Tarih ödevi' })).toHaveAccessibleDescription(
      'Yarın',
    )
    expect(screen.getByRole('checkbox', { name: 'Biyoloji projesi' })).toHaveAccessibleDescription(
      '4 gün sonra',
    )
    expect(
      screen.getByRole('progressbar', { name: 'Bugünün görevleri ilerlemesi' }),
    ).toHaveAttribute('aria-valuenow', '0')
    expect(screen.queryByText(/görev daha/)).not.toBeInTheDocument()
  })

  it('en fazla 6 görev gösterir; fazlası için ipucu verir', async () => {
    for (let i = 0; i < 8; i += 1) await routine(repos, `Rutin ${i + 1}`, i)
    renderCard()

    expect(await screen.findByText('0 / 8 tamamlandı')).toBeInTheDocument()
    expect(within(card()).getAllByRole('checkbox')).toHaveLength(6)
    expect(screen.getByText('+2 görev daha')).toBeInTheDocument()
  })

  it('rutini tamamlar ve geri alır (tamamlama oluşturulur, sonra silinir)', async () => {
    const user = userEvent.setup()
    const task = await routine(repos, 'Paragraf çöz')
    renderCard()

    const checkbox = await screen.findByRole('checkbox', { name: 'Paragraf çöz' })
    expect(checkbox).toHaveAttribute('aria-checked', 'false')

    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'true'))
    expect(await repos.taskCompletions.findByTask(task.id)).toHaveLength(1)
    expect(screen.getByText('1 / 1 tamamlandı')).toBeInTheDocument()
    expect(screen.getByText('Bugünlük hepsi tamam!')).toBeInTheDocument()

    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'false'))
    expect(await repos.taskCompletions.findByTask(task.id)).toEqual([])
    expect(screen.queryByText('Bugünlük hepsi tamam!')).not.toBeInTheDocument()
  })

  it('ödevi tamamlar (completedAt dolar) ve geri alır (temizlenir)', async () => {
    const user = userEvent.setup()
    const task = await assignment(repos, 'Kimya özeti', TODAY)
    renderCard()

    const checkbox = await screen.findByRole('checkbox', { name: 'Kimya özeti' })
    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'true'))
    expect((await repos.tasks.findById(task.id))?.completedAt).toBe(NOW.toISOString())

    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'false'))
    expect((await repos.tasks.findById(task.id))?.completedAt).toBeNull()
  })

  it('yazma başarısız olursa uyarı gösterir ve hatayı günlüğe yazar', async () => {
    const user = userEvent.setup()
    await routine(repos, 'Paragraf çöz')
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(repos.taskCompletions, 'create').mockRejectedValue(new Error('disk dolu'))
    renderCard()

    const checkbox = await screen.findByRole('checkbox', { name: 'Paragraf çöz' })
    await user.click(checkbox)

    expect(await screen.findByRole('alert')).toHaveTextContent('Görev güncellenemedi. Tekrar dene.')
    expect(consoleError).toHaveBeenCalled()
    expect(checkbox).toHaveAttribute('aria-checked', 'false')
    expect(checkbox).toBeEnabled()
  })
})
