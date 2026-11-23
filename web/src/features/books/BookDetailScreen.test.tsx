import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, Outlet, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import type { Book } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { addProgress, createBook, type BookInput } from './bookActions'
import { BookDetailScreen } from './BookDetailScreen'
import { bookPath } from './paths'

const DAY_MS = 24 * 60 * 60 * 1000

function renderDetail(services: AppServices, bookId: string) {
  const router = createMemoryRouter(
    [
      {
        path: ROUTES.books,
        element: <Outlet />,
        children: [
          { index: true, element: <p>Kitap listesi</p> },
          { path: ':bookId', Component: BookDetailScreen },
        ],
      },
    ],
    { initialEntries: [bookPath(bookId)] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return { router, user: userEvent.setup() }
}

function seedBook(services: AppServices, overrides: Partial<BookInput> = {}): Promise<Book> {
  return createBook(services.repositories, {
    title: 'Limit Matematik',
    publisher: 'Yayınevi A',
    kind: 'questionBank',
    subjectId: null,
    unit: 'test',
    totalUnits: 120,
    ...overrides,
  })
}

function daysAgo(days: number): Date {
  return new Date(Date.now() - days * DAY_MS)
}

async function enterProgress(user: ReturnType<typeof userEvent.setup>, value: string) {
  await user.click(screen.getByRole('button', { name: 'İlerleme gir' }))
  const dialog = await screen.findByRole('dialog', { name: 'İlerleme gir' })
  const input = within(dialog).getByLabelText('Ulaştığın test')
  await user.clear(input)
  await user.type(input, value)
  await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))
}

describe('BookDetailScreen', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('başlığı, künyeyi, yüzdeyi ve sayacı gösterir', async () => {
    const book = await seedBook(services)
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 30, note: null })
    renderDetail(services, book.id)

    expect(
      await screen.findByRole('heading', { level: 1, name: 'Limit Matematik' }),
    ).toBeInTheDocument()
    expect(screen.getByText('Soru bankası · Yayınevi A')).toBeInTheDocument()
    expect(screen.getByRole('progressbar', { name: 'Kitap ilerlemesi' })).toHaveAttribute(
      'aria-valuenow',
      '25',
    )
    expect(screen.getByText('%25')).toBeInTheDocument()
    expect(screen.getByText('30 / 120 test')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Kitaplar' })).toHaveAttribute('href', ROUTES.books)
  })

  it('künyede dersin adını gösterir', async () => {
    const subject = await services.repositories.subjects.create({
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY'],
      catalogKey: null,
      order: 1,
    })
    const book = await seedBook(services, { subjectId: subject.id, publisher: null })
    renderDetail(services, book.id)

    expect(await screen.findByText('Soru bankası · Matematik')).toBeInTheDocument()
  })

  it('ilerleme girince çubuk ve yüzde güncellenir, geçmişe eklenir', async () => {
    const book = await seedBook(services)
    const { user } = renderDetail(services, book.id)
    await screen.findByRole('heading', { level: 1, name: 'Limit Matematik' })
    expect(await screen.findByText('Henüz ilerleme girmedin.')).toBeInTheDocument()
    expect(screen.getByText('Henüz yok')).toBeInTheDocument()

    await enterProgress(user, '60')

    expect(await screen.findByText('%50')).toBeInTheDocument()
    expect(screen.getByRole('progressbar', { name: 'Kitap ilerlemesi' })).toHaveAttribute(
      'aria-valuenow',
      '50',
    )
    expect(screen.queryByRole('dialog', { name: 'İlerleme gir' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Test 60 kaydını sil' })).toBeInTheDocument()
  })

  it('toplama ulaşınca "Tamamlandı" gösterir', async () => {
    const book = await seedBook(services)
    const { user } = renderDetail(services, book.id)
    await screen.findByRole('heading', { level: 1, name: 'Limit Matematik' })

    await enterProgress(user, '120')

    expect(await screen.findByText('%100')).toBeInTheDocument()
    // Rozet + "Tahmini bitiş" satırı.
    expect(screen.getAllByText('Tamamlandı')).toHaveLength(2)
  })

  it('toplam bilinmiyorsa çubuk yerine sayaç ve "Toplam bilinmiyor" gösterir', async () => {
    const book = await seedBook(services, { totalUnits: null, unit: 'page' })
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 45, note: null })
    renderDetail(services, book.id)

    expect(await screen.findByText('45 sayfa')).toBeInTheDocument()
    expect(screen.getByText('Toplam bilinmiyor')).toBeInTheDocument()
    expect(screen.getByText('Toplam girilirse hesaplanır')).toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('son 7 günlük hızı ve tahmini bitişi gösterir', async () => {
    const book = await seedBook(services)
    const repos = services.repositories
    await addProgress(repos, { bookId: book.id, reachedUnit: 10, note: null }, daysAgo(10))
    await addProgress(repos, { bookId: book.id, reachedUnit: 40, note: null }, daysAgo(0.01))
    renderDetail(services, book.id)

    // Hız: 40 − 10 = 30/hafta; kalan 80 → ⌈80 / (30/7)⌉ = 19 gün.
    expect(await screen.findByText('haftada ~30 test')).toBeInTheDocument()
    expect(screen.getByText(/\(~19 gün\)$/)).toBeInTheDocument()
  })

  it('hız hesaplanamıyorsa açıklama gösterir', async () => {
    const book = await seedBook(services)
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 5, note: null })
    renderDetail(services, book.id)

    expect(await screen.findByText('Yeterli veri yok')).toBeInTheDocument()
    expect(screen.getByText('Hız belli olunca hesaplanır')).toBeInTheDocument()
  })

  it('geçmiş kayıtları notuyla listeler ve silinebilir', async () => {
    const book = await seedBook(services)
    const repos = services.repositories
    await addProgress(repos, { bookId: book.id, reachedUnit: 12, note: 'Türev' }, daysAgo(2))
    await addProgress(repos, { bookId: book.id, reachedUnit: 20, note: null }, daysAgo(1))
    const { user } = renderDetail(services, book.id)

    const history = await screen.findByRole('region', { name: 'Geçmiş' })
    expect(within(history).getByText('Test 20')).toBeInTheDocument()
    expect(within(history).getByText(/· Türev$/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Test 20 kaydını sil' }))

    expect(await screen.findByText('12 / 120 test')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Test 20 kaydını sil' })).not.toBeInTheDocument()
    expect(await repos.bookProgress.findByBook(book.id)).toHaveLength(1)
  })

  it('rafa kaldırır ve raftan geri alır', async () => {
    const book = await seedBook(services)
    const { user } = renderDetail(services, book.id)

    await user.click(await screen.findByRole('button', { name: 'Rafa kaldır' }))

    expect(await screen.findByText('Arşivlendi')).toBeInTheDocument()
    expect((await services.repositories.books.findById(book.id))?.archivedAt).not.toBeNull()

    await user.click(screen.getByRole('button', { name: 'Raftan geri al' }))

    expect(await screen.findByRole('button', { name: 'Rafa kaldır' })).toBeInTheDocument()
    expect(screen.queryByText('Arşivlendi')).not.toBeInTheDocument()
  })

  it('işlem başarısız olursa hata mesajı gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.books, 'update').mockRejectedValue(new Error('disk'))
    const book = await seedBook(services)
    const { user } = renderDetail(services, book.id)

    await user.click(await screen.findByRole('button', { name: 'Rafa kaldır' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('İşlem tamamlanamadı')
  })

  it('"Düzenle" kitap formunu düzenleme modunda açar', async () => {
    const book = await seedBook(services)
    const { user } = renderDetail(services, book.id)

    await user.click(await screen.findByRole('button', { name: 'Düzenle' }))

    expect(await screen.findByRole('dialog', { name: 'Kitabı düzenle' })).toBeInTheDocument()
  })

  it('silme onayında "Vazgeç" kitabı korur', async () => {
    const book = await seedBook(services)
    const { user, router } = renderDetail(services, book.id)

    await user.click(await screen.findByRole('button', { name: 'Kitabı sil' }))
    const dialog = await screen.findByRole('dialog', { name: 'Kitabı sil?' })
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }))

    expect(screen.queryByRole('dialog', { name: 'Kitabı sil?' })).not.toBeInTheDocument()
    expect(router.state.location.pathname).toBe(bookPath(book.id))
    expect(await services.repositories.books.findById(book.id)).toBeDefined()
  })

  it('silmeyi onaylayınca kitabı ve kayıtlarını siler, listeye döner', async () => {
    const book = await seedBook(services)
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 3, note: null })
    const { user, router } = renderDetail(services, book.id)

    await user.click(await screen.findByRole('button', { name: 'Kitabı sil' }))
    const dialog = await screen.findByRole('dialog', { name: 'Kitabı sil?' })
    expect(dialog).toHaveAccessibleDescription('Kitap ve tüm ilerleme geçmişi silinecek.')
    await user.click(within(dialog).getByRole('button', { name: 'Sil' }))

    expect(await screen.findByText('Kitap listesi')).toBeInTheDocument()
    expect(router.state.location.pathname).toBe(ROUTES.books)
    expect(await services.repositories.books.findById(book.id)).toBeUndefined()
    expect(await services.repositories.bookProgress.findByBook(book.id)).toHaveLength(0)
  })

  it('kitap yoksa "Kitap bulunamadı" ve listeye dönüş bağlantısı gösterir', async () => {
    renderDetail(services, crypto.randomUUID())

    expect(await screen.findByRole('heading', { name: 'Kitap bulunamadı' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Kitaplara dön' })).toHaveAttribute(
      'href',
      ROUTES.books,
    )
  })

  describe('bölümler ve barkod', () => {
    it('bölümleri aralık ve konu adıyla, barkodu ayrı satırda gösterir', async () => {
      const subject = await services.repositories.subjects.create({
        name: 'Matematik',
        exam: 'TYT',
        fields: ['SAY'],
        catalogKey: null,
        order: 0,
      })
      const topic = await services.repositories.topics.create({
        subjectId: subject.id,
        name: 'Türev',
        catalogKey: null,
        order: 0,
      })
      const book = await seedBook(services, {
        barcode: '9781234567897',
        sections: [
          { title: 'Giriş', order: 1, startUnit: 1, endUnit: 12, topicId: topic.id },
          { title: 'Karma', order: 2, startUnit: null, endUnit: null, topicId: null },
        ],
      })

      renderDetail(services, book.id)

      const sections = await screen.findByRole('region', { name: 'Bölümler' })
      expect(within(sections).getByText('Giriş')).toBeInTheDocument()
      expect(within(sections).getByText('Test 1–12 · Türev')).toBeInTheDocument()
      expect(within(sections).getByText('Karma')).toBeInTheDocument()
      expect(screen.getByText('Barkod')).toBeInTheDocument()
      expect(screen.getByText('9781234567897')).toBeInTheDocument()
    })

    it('bölümü ve barkodu olmayan kitapta bu bölümler görünmez', async () => {
      const book = await seedBook(services)
      renderDetail(services, book.id)
      await screen.findByRole('heading', { name: 'Limit Matematik' })
      expect(screen.queryByRole('region', { name: 'Bölümler' })).not.toBeInTheDocument()
      expect(screen.queryByText('Barkod')).not.toBeInTheDocument()
    })
  })
})
