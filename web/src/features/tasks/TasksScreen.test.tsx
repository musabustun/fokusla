import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { AppServices } from '@/data'
import type { TestServices } from '@/test/services'
import { HIDE_COMPLETED_STORAGE_KEY } from './useHideCompleted'
import {
  assignment,
  renderScreen,
  seedSubjects,
  seedTask,
  setupServices,
  teardownServices,
  values,
} from './testUtils'

function section(name: string) {
  return screen.getByRole('region', { name })
}

async function findSection(name: string) {
  return screen.findByRole('region', { name })
}

describe('TasksScreen', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(async () => {
    ctx = await setupServices()
    services = ctx.services
  })

  afterEach(async () => {
    await teardownServices(ctx)
  })

  it('başlık, tarih ve boş durum gösterir', async () => {
    renderScreen(services)
    expect(screen.getByRole('heading', { level: 1, name: 'Görevler' })).toBeInTheDocument()
    expect(screen.getByText('19 Kasım Perşembe')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'Bugün için görev yok' })).toBeVisible()
    expect(screen.getByRole('radiogroup', { name: 'Görünüm' })).toBeInTheDocument()
    expect(screen.getByRole('radio', { name: 'Bugün' })).toHaveAttribute('aria-checked', 'true')
  })

  it('rutin ekler; alanın dersleri gruplu listelenir ve rutin Bugün görünümünde çıkar', async () => {
    const user = userEvent.setup()
    await seedSubjects(services.repositories)
    renderScreen(services)

    await user.click(screen.getByRole('button', { name: 'Görev ekle' }))
    const dialog = await screen.findByRole('dialog', { name: 'Yeni görev' })
    expect(within(dialog).getByRole('radio', { name: 'Rutin' })).toHaveAttribute(
      'aria-checked',
      'true',
    )

    await user.type(within(dialog).getByLabelText('Başlık'), '50 paragraf sorusu')
    await user.type(within(dialog).getByLabelText('Hedef miktar'), '50')
    await user.type(within(dialog).getByLabelText('Birim'), 'soru')
    const subjectSelect = within(dialog).getByLabelText('Ders')
    await waitFor(() =>
      expect(within(subjectSelect).getByRole('option', { name: 'Fizik' })).toBeInTheDocument(),
    )
    expect(within(subjectSelect).getByRole('option', { name: 'Ders yok' })).toBeInTheDocument()
    expect(within(subjectSelect).queryByRole('option', { name: 'Tarih' })).not.toBeInTheDocument()
    expect(within(subjectSelect).getByRole('group', { name: 'TYT' })).toBeInTheDocument()
    await user.selectOptions(subjectSelect, 'Türkçe')
    await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    const routines = await findSection('Rutinler')
    expect(within(routines).getByRole('checkbox', { name: '50 paragraf sorusu' })).toHaveAttribute(
      'aria-checked',
      'false',
    )
    expect(
      within(routines).getByRole('button', { name: 'Ayrıntılar: 50 paragraf sorusu' }),
    ).toHaveAccessibleDescription(/Türkçe\s*·\s*50 soru/)
    const [task] = await services.repositories.tasks.findAll()
    expect(task).toMatchObject({
      kind: 'routine',
      targetQuantity: 50,
      quantityUnit: 'soru',
      startDate: '2026-11-19',
      recurrence: { frequency: 'daily', weekdays: [] },
    })
  })

  it('bugün teslim ödev ekler ve "Bugün teslim" bölümünde gösterir', async () => {
    const user = userEvent.setup()
    renderScreen(services)

    await user.click(screen.getByRole('button', { name: 'Görev ekle' }))
    const dialog = await screen.findByRole('dialog', { name: 'Yeni görev' })
    await user.click(within(dialog).getByRole('radio', { name: 'Ödev' }))
    expect(within(dialog).getByLabelText('Son tarih')).toHaveValue('2026-11-19')
    expect(within(dialog).queryByRole('radiogroup', { name: 'Tekrar' })).not.toBeInTheDocument()
    await user.type(within(dialog).getByLabelText('Başlık'), 'Fizik ödev föyü 3')
    await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))

    const dueToday = await findSection('Bugün teslim')
    expect(within(dueToday).getByRole('checkbox', { name: 'Fizik ödev föyü 3' })).toBeVisible()
  })

  it('doğrulama hatalarını alanın altında gösterir ve düzeltince kaldırır', async () => {
    const user = userEvent.setup()
    renderScreen(services)
    await user.click(screen.getByRole('button', { name: 'Görev ekle' }))
    const dialog = await screen.findByRole('dialog', { name: 'Yeni görev' })

    await user.click(within(dialog).getByRole('radio', { name: 'Belirli günler' }))
    await user.type(within(dialog).getByLabelText('Hedef miktar'), '0')
    await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))

    const title = within(dialog).getByLabelText('Başlık')
    expect(title).toHaveAttribute('aria-invalid', 'true')
    expect(title).toHaveAccessibleDescription('Başlık gerekli')
    expect(within(dialog).getByText('En az bir gün seç')).toBeVisible()
    expect(within(dialog).getByLabelText('Hedef miktar')).toHaveAccessibleDescription(
      'Pozitif bir tam sayı gir',
    )
    expect(screen.getByRole('dialog', { name: 'Yeni görev' })).toBeInTheDocument()

    await user.type(title, 'Deneme')
    await user.click(within(dialog).getByRole('button', { name: 'Pazartesi' }))
    expect(title).not.toHaveAttribute('aria-invalid')
    expect(within(dialog).queryByText('En az bir gün seç')).not.toBeInTheDocument()
    expect(await services.repositories.tasks.findAll()).toHaveLength(0)
  })

  it('tek dokunuşla tamamlar ve geri alır', async () => {
    const user = userEvent.setup()
    await seedTask(services.repositories, values({ title: 'Kelime çalış' }))
    renderScreen(services)

    const checkbox = await screen.findByRole('checkbox', { name: 'Kelime çalış' })
    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'true'))
    expect(await services.repositories.taskCompletions.findByDate('2026-11-19')).toHaveLength(1)

    await user.click(checkbox)
    await waitFor(() => expect(checkbox).toHaveAttribute('aria-checked', 'false'))
    expect(await services.repositories.taskCompletions.findByDate('2026-11-19')).toHaveLength(0)
  })

  it('tamamlananları gizler ve tercihi saklar', async () => {
    const user = userEvent.setup()
    await seedTask(services.repositories, values({ title: 'Kelime çalış' }))
    await seedTask(services.repositories, values({ title: 'Paragraf' }))
    renderScreen(services)

    await user.click(await screen.findByRole('checkbox', { name: 'Kelime çalış' }))
    await waitFor(() =>
      expect(screen.getByRole('checkbox', { name: 'Kelime çalış' })).toHaveAttribute(
        'aria-checked',
        'true',
      ),
    )

    await user.click(screen.getByRole('button', { name: 'Tamamlananları gizle' }))

    expect(screen.queryByRole('checkbox', { name: 'Kelime çalış' })).not.toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: 'Paragraf' })).toBeVisible()
    expect(screen.getByRole('button', { name: 'Tamamlananları göster' })).toBeVisible()
    expect(localStorage.getItem(HIDE_COMPLETED_STORAGE_KEY)).toBe('true')

    await user.click(screen.getByRole('checkbox', { name: 'Paragraf' }))
    expect(await screen.findByRole('heading', { name: 'Bugünkü görevlerin tamam' })).toBeVisible()

    await user.click(screen.getByRole('button', { name: 'Tamamlananları göster' }))
    expect(screen.getByRole('checkbox', { name: 'Kelime çalış' })).toBeVisible()
  })

  it('geciken ödevi renk dışında ikon ve metinle vurgular', async () => {
    await seedTask(services.repositories, assignment('Kimya föyü', '2026-11-16'))
    await seedTask(services.repositories, assignment('Deneme analizi', '2026-11-21'))
    renderScreen(services)

    const overdue = await findSection('Geciken')
    const label = within(overdue).getByText('3 gün gecikti')
    expect(label.closest('.text-danger')).not.toBeNull()
    expect(label.querySelector('svg')).not.toBeNull()

    const upcoming = section('Yaklaşan')
    expect(within(upcoming).getByText('2 gün kaldı')).toBeInTheDocument()
  })

  it('Tümü görünümü rutinleri, açık ve tamamlanan ödevleri listeler', async () => {
    const user = userEvent.setup()
    await seedTask(
      services.repositories,
      values({
        title: 'Pazartesi denemesi',
        recurrence: { frequency: 'weekly', weekdays: [1, 3] },
      }),
    )
    const done = await seedTask(services.repositories, assignment('Eski ödev', '2026-11-10'))
    await services.repositories.tasks.update(done.id, { completedAt: '2026-11-10T09:00:00.000Z' })
    await seedTask(services.repositories, assignment('Uzak ödev', '2026-12-30'))
    renderScreen(services)

    await user.click(await screen.findByRole('radio', { name: 'Tümü' }))

    const routines = await findSection('Rutinler')
    expect(within(routines).getByText(/Pzt, Çar/)).toBeInTheDocument()
    // Perşembe planlı değil: işaretlenemez.
    expect(within(routines).getByRole('checkbox', { name: 'Pazartesi denemesi' })).toBeDisabled()
    expect(within(section('Ödevler')).getByText(/41 gün kaldı/)).toBeInTheDocument()
    expect(
      within(section('Tamamlanan ödevler')).getByRole('checkbox', { name: 'Eski ödev' }),
    ).toHaveAttribute('aria-checked', 'true')

    await user.click(screen.getByRole('button', { name: 'Tamamlananları gizle' }))
    expect(screen.queryByRole('region', { name: 'Tamamlanan ödevler' })).not.toBeInTheDocument()
  })

  it('yazma hatasını kullanıcıya gösterir', async () => {
    const user = userEvent.setup()
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.taskCompletions, 'create').mockRejectedValue(new Error('disk'))
    await seedTask(services.repositories, values({ title: 'Kelime çalış' }))
    renderScreen(services)

    await user.click(await screen.findByRole('checkbox', { name: 'Kelime çalış' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Değişiklik kaydedilemedi')
  })
})
