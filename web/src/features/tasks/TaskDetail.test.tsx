import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { AppServices } from '@/data'
import type { TestServices } from '@/test/services'
import {
  assignment,
  renderScreen,
  seedSubjects,
  seedTask,
  setupServices,
  teardownServices,
  values,
} from './testUtils'

function stubWideScreen(matches: boolean) {
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => ({
      matches,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
    })),
  )
}

describe('Görev ayrıntısı', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(async () => {
    ctx = await setupServices()
    services = ctx.services
  })

  afterEach(async () => {
    vi.unstubAllGlobals()
    await teardownServices(ctx)
  })

  describe('iPhone (sheet)', () => {
    it('rutin ayrıntısını, oranı ve seriyi gösterir; tamamla/geri al çalışır', async () => {
      const user = userEvent.setup()
      const subjects = await seedSubjects(services.repositories)
      const task = await seedTask(
        services.repositories,
        values({
          title: '50 paragraf sorusu',
          subjectId: subjects.Türkçe?.id ?? null,
          targetQuantity: 50,
          quantityUnit: 'soru',
          notes: 'Hız çalış',
        }),
        '2026-11-15',
      )
      for (const date of ['2026-11-17', '2026-11-18']) {
        await services.repositories.taskCompletions.create({
          taskId: task.id,
          date,
          completedAt: `${date}T10:00:00.000Z`,
          quantity: null,
        })
      }
      renderScreen(services)

      await user.click(
        await screen.findByRole('button', { name: 'Ayrıntılar: 50 paragraf sorusu' }),
      )
      const dialog = await screen.findByRole('dialog', { name: '50 paragraf sorusu' })
      expect(within(dialog).getByRole('heading', { name: '50 paragraf sorusu' })).toBeVisible()
      expect(within(dialog).getByText('Her gün')).toBeVisible()
      expect(within(dialog).getByText('Türkçe')).toBeVisible()
      expect(within(dialog).getByText('Hız çalış')).toBeVisible()
      const ring = within(dialog).getByRole('progressbar', { name: 'Son 7 gün tamamlama oranı' })
      expect(ring).toHaveAttribute('aria-valuenow', '40')
      expect(within(ring).getByText('2/5')).toBeInTheDocument()
      expect(within(dialog).getByText('2 gün seri')).toBeVisible()

      await user.click(within(dialog).getByRole('button', { name: 'Tamamla' }))
      expect(await within(dialog).findByRole('button', { name: 'Geri al' })).toBeVisible()
      expect(within(dialog).getByText('3 gün seri')).toBeVisible()
      await user.click(within(dialog).getByRole('button', { name: 'Geri al' }))
      expect(await within(dialog).findByRole('button', { name: 'Tamamla' })).toBeVisible()

      await user.click(within(dialog).getByRole('button', { name: 'Kapat' }))
      await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    })

    it('gerçekleşen miktarı kaydeder ve görevi tamamlar', async () => {
      const user = userEvent.setup()
      await seedTask(
        services.repositories,
        values({ title: 'Paragraf', targetQuantity: 50, quantityUnit: 'soru' }),
      )
      renderScreen(services)

      await user.click(await screen.findByRole('button', { name: 'Ayrıntılar: Paragraf' }))
      const dialog = await screen.findByRole('dialog', { name: 'Paragraf' })
      const input = within(dialog).getByLabelText('Gerçekleşen miktar')

      await user.type(input, '0')
      await user.click(within(dialog).getByRole('button', { name: 'Miktarı kaydet' }))
      expect(input).toHaveAccessibleDescription('1 ile 10.000 arasında bir tam sayı gir')

      await user.clear(input)
      await user.type(input, '42')
      await user.click(within(dialog).getByRole('button', { name: 'Miktarı kaydet' }))

      expect(await within(dialog).findByRole('button', { name: 'Geri al' })).toBeVisible()
      expect(within(dialog).getByLabelText('Gerçekleşen miktar')).toHaveValue(42)
      expect(screen.getByRole('checkbox', { name: 'Paragraf' })).toHaveAttribute(
        'aria-checked',
        'true',
      )
      expect(screen.getAllByText(/42\/50 soru/).length).toBeGreaterThan(0)
    })

    it('ödevi düzenler (tür değiştirilemez) ve siler', async () => {
      const user = userEvent.setup()
      await seedTask(services.repositories, assignment('Fizik ödevi', '2026-11-20'))
      renderScreen(services)

      await user.click(await screen.findByRole('button', { name: 'Ayrıntılar: Fizik ödevi' }))
      let dialog = await screen.findByRole('dialog', { name: 'Fizik ödevi' })
      expect(within(dialog).getByText('20 Kasım 2026')).toBeVisible()
      expect(within(dialog).getByText('Yarın')).toBeVisible()

      await user.click(within(dialog).getByRole('button', { name: 'Düzenle' }))
      expect(within(dialog).queryByRole('radiogroup', { name: 'Tür' })).not.toBeInTheDocument()
      const title = within(dialog).getByLabelText('Başlık')
      expect(title).toHaveValue('Fizik ödevi')
      await user.clear(title)
      await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))
      expect(title).toHaveAccessibleDescription('Başlık gerekli')

      await user.type(title, 'Fizik ödev föyü 3')
      await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))
      dialog = await screen.findByRole('dialog', { name: 'Fizik ödev föyü 3' })
      expect(within(dialog).getByRole('button', { name: 'Düzenle' })).toBeVisible()

      await user.click(within(dialog).getByRole('button', { name: 'Düzenle' }))
      await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }))
      await user.click(within(dialog).getByRole('button', { name: 'Sil' }))
      const confirm = within(dialog).getByRole('group', { name: 'Bu görev silinsin mi?' })
      await user.click(within(confirm).getByRole('button', { name: 'Vazgeç' }))
      expect(within(dialog).queryByText('Bu görev silinsin mi?')).not.toBeInTheDocument()

      await user.click(within(dialog).getByRole('button', { name: 'Sil' }))
      await user.click(
        within(within(dialog).getByRole('group', { name: 'Bu görev silinsin mi?' })).getByRole(
          'button',
          { name: 'Sil' },
        ),
      )
      await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
      expect(screen.queryByRole('checkbox', { name: 'Fizik ödev föyü 3' })).not.toBeInTheDocument()
      expect(await services.repositories.tasks.findAll()).toHaveLength(0)
    })

    it('planlı olmadığı gün rutini işaretletmez', async () => {
      const user = userEvent.setup()
      await seedTask(
        services.repositories,
        values({
          title: 'Hafta sonu denemesi',
          recurrence: { frequency: 'weekly', weekdays: [6, 7] },
        }),
      )
      renderScreen(services)
      await user.click(await screen.findByRole('radio', { name: 'Tümü' }))
      await user.click(
        await screen.findByRole('button', { name: 'Ayrıntılar: Hafta sonu denemesi' }),
      )
      const dialog = await screen.findByRole('dialog', { name: 'Hafta sonu denemesi' })
      expect(within(dialog).getByRole('button', { name: 'Tamamla' })).toBeDisabled()
      expect(within(dialog).getByText('Bu rutin bugün planlı değil.')).toBeVisible()
      expect(within(dialog).getByText('Hafta sonu')).toBeVisible()
    })

    it('silme hatasını gösterir ve sayfayı açık tutar', async () => {
      const user = userEvent.setup()
      vi.spyOn(console, 'error').mockImplementation(() => undefined)
      vi.spyOn(services.repositories.tasks, 'delete').mockRejectedValue(new Error('disk'))
      await seedTask(services.repositories, values({ title: 'Kelime' }))
      renderScreen(services)

      await user.click(await screen.findByRole('button', { name: 'Ayrıntılar: Kelime' }))
      const dialog = await screen.findByRole('dialog', { name: 'Kelime' })
      await user.click(within(dialog).getByRole('button', { name: 'Sil' }))
      await user.click(
        within(within(dialog).getByRole('group', { name: 'Bu görev silinsin mi?' })).getByRole(
          'button',
          { name: 'Sil' },
        ),
      )
      expect(await within(dialog).findByRole('alert')).toHaveTextContent('kaydedilemedi')
      expect(screen.getByRole('dialog', { name: 'Kelime' })).toBeInTheDocument()
    })
  })

  describe('iPad (yan panel)', () => {
    it('seçili görevi yan panelde gösterir', async () => {
      stubWideScreen(true)
      const user = userEvent.setup()
      await seedTask(services.repositories, values({ title: 'Paragraf' }))
      renderScreen(services)

      const pane = screen.getByRole('complementary', { name: 'Görev ayrıntıları' })
      expect(within(pane).getByText('Ayrıntıları görmek için bir görev seç')).toBeVisible()

      const row = await screen.findByRole('button', { name: 'Ayrıntılar: Paragraf' })
      await user.click(row)
      expect(within(pane).getByRole('heading', { level: 2, name: 'Paragraf' })).toBeVisible()
      expect(row).toHaveAttribute('aria-current', 'true')
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()

      await user.click(within(pane).getByRole('button', { name: 'Sil' }))
      await user.click(
        within(within(pane).getByRole('group', { name: 'Bu görev silinsin mi?' })).getByRole(
          'button',
          { name: 'Sil' },
        ),
      )
      expect(await within(pane).findByText('Ayrıntıları görmek için bir görev seç')).toBeVisible()
    })
  })
})
