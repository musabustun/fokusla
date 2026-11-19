import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider, useParams } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import type { Book, Subject } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { addProgress, createBook, setBookArchived, type BookInput } from './bookActions'
import { BooksScreen } from './BooksScreen'
import { bookPath } from './paths'

/** Detay ekranının yerine geçen basit taslak (detay ayrı bir dosyada test edilir). */
function DetailStub() {
  const { bookId } = useParams()
  return <h1>Detay {bookId}</h1>
}

function renderBooks(services: AppServices, initialPath: string = ROUTES.books) {
  const router = createMemoryRouter(
    [
      {
        path: ROUTES.books,
        Component: BooksScreen,
        children: [{ path: ':bookId', Component: DetailStub }],
      },
    ],
    { initialEntries: [initialPath] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return { router, user: userEvent.setup() }
}

function stubWideLayout() {
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => ({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  )
}

const BASE_INPUT: BookInput = {
  title: 'Kitap',
  publisher: null,
  kind: 'questionBank',
  subjectId: null,
  unit: 'test',
  totalUnits: null,
}

describe('BooksScreen', () => {
  let ctx: TestServices
  let services: AppServices
  let math: Subject

  const addBook = (input: Partial<BookInput>): Promise<Book> =>
    createBook(services.repositories, { ...BASE_INPUT, ...input })

  beforeEach(async () => {
    ctx = createTestServices()
    services = ctx.services
    math = await services.repositories.subjects.create({
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY', 'EA'],
      catalogKey: null,
      order: 0,
    })
  })

  afterEach(async () => {
    vi.unstubAllGlobals()
    await ctx.dispose()
  })

  it('kitap yoksa boş durumu gösterir ve oradan ekleme formunu açar', async () => {
    const { user } = renderBooks(services)

    expect(screen.getByRole('heading', { level: 1, name: 'Kitaplar' })).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'Kitaplığın boş' })).toBeInTheDocument()
    expect(screen.queryByRole('radiogroup', { name: 'Kitap durumu' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'İlk kitabını ekle' }))

    expect(screen.getByRole('dialog', { name: 'Kitap ekle' })).toBeInTheDocument()
  })

  it('başlıktaki "Kitap ekle" ile kitap oluşturur ve detayına gider', async () => {
    const { router, user } = renderBooks(services)
    await screen.findByRole('heading', { name: 'Kitaplığın boş' })

    await user.click(screen.getByRole('button', { name: 'Kitap ekle' }))
    const dialog = screen.getByRole('dialog', { name: 'Kitap ekle' })
    await user.type(within(dialog).getByLabelText('Kitap adı'), 'Paraf TYT Matematik')
    await user.selectOptions(within(dialog).getByLabelText('Ders'), 'Matematik')
    await user.type(within(dialog).getByLabelText('Toplam'), '40')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    const [book] = await vi.waitFor(async () => {
      const books = await services.repositories.books.findAll()
      expect(books).toHaveLength(1)
      return books
    })
    expect(await screen.findByRole('heading', { name: `Detay ${book?.id}` })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe(bookPath(book?.id ?? ''))
    // iPhone düzeni: detay açıkken liste gösterilmez.
    expect(screen.queryByRole('heading', { name: 'Kitaplar' })).not.toBeInTheDocument()
  })

  it('kitapları derse göre gruplar; ders seçilmemişler en sonda', async () => {
    await addBook({ title: 'Genel Deneme' })
    await addBook({ title: 'Paraf TYT Matematik', subjectId: math.id, totalUnits: 40 })
    renderBooks(services)

    const sections = await screen.findAllByRole('heading', { level: 2 })
    expect(sections.map((h) => h.textContent)).toEqual(['Matematik', 'Ders seçilmedi'])
    const mathSection = screen.getByRole('region', { name: 'Matematik' })
    expect(within(mathSection).getByRole('link', { name: /Paraf TYT Matematik/ })).toHaveAttribute(
      'href',
      expect.stringMatching(/^\/kitaplar\//),
    )
    expect(within(mathSection).getByRole('link')).toHaveTextContent('0 / 40 test')
    expect(within(mathSection).getByRole('link')).toHaveTextContent('%0')
  })

  it('satır ilerleme, hız ve yüzde gösterir', async () => {
    const book = await addBook({ title: 'Fasikül', unit: 'page', totalUnits: 200 })
    const now = Date.now()
    await addProgress(
      services.repositories,
      { bookId: book.id, reachedUnit: 20, note: null },
      new Date(now - 3 * 24 * 60 * 60 * 1000),
    )
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 50, note: null })
    renderBooks(services)

    const link = await screen.findByRole('link', { name: /Fasikül/ })
    expect(link).toHaveTextContent('Soru bankası · 50 / 200 sayfa · haftada ~30 sayfa')
    expect(link).toHaveTextContent('%25')
    expect(link).not.toHaveAttribute('aria-current')
  })

  it('"Devam eden" ve "Biten" sekmeleri kitapları ayırır', async () => {
    await addBook({ title: 'Yarım Kitap', totalUnits: 10 })
    const done = await addBook({ title: 'Biten Kitap', totalUnits: 10 })
    await addProgress(services.repositories, { bookId: done.id, reachedUnit: 10, note: null })
    const shelved = await addBook({ title: 'Rafta Kitap' })
    await setBookArchived(services.repositories, shelved.id, true)
    const { user } = renderBooks(services)

    const tabs = await screen.findByRole('radiogroup', { name: 'Kitap durumu' })
    expect(within(tabs).getByRole('radio', { name: 'Devam eden' })).toBeChecked()
    expect(screen.getByRole('link', { name: /Yarım Kitap/ })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /Biten Kitap/ })).not.toBeInTheDocument()

    await user.click(within(tabs).getByRole('radio', { name: 'Biten' }))

    expect(screen.queryByRole('link', { name: /Yarım Kitap/ })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Biten Kitap/ })).toHaveTextContent('Tamamlandı')
    expect(screen.getByRole('link', { name: /Rafta Kitap/ })).toHaveTextContent('Arşivlendi')
  })

  it('boş sekmede kısa bir açıklama gösterir', async () => {
    await addBook({ title: 'Yarım Kitap' })
    const { user } = renderBooks(services)

    await user.click(await screen.findByRole('radio', { name: 'Biten' }))

    expect(screen.getByText('Biten kitap yok.')).toBeInTheDocument()
  })

  it('tüm kitaplar bittiyse "Devam eden" sekmesi boş metni gösterir', async () => {
    const shelved = await addBook({ title: 'Rafta Kitap' })
    await setBookArchived(services.repositories, shelved.id, true)
    renderBooks(services)

    expect(await screen.findByText('Devam eden kitap yok.')).toBeInTheDocument()
  })

  describe('iPad (geniş) düzen', () => {
    beforeEach(() => {
      stubWideLayout()
    })

    it('kitap seçili değilse detay sütununda yönlendirme gösterir', async () => {
      await addBook({ title: 'Paraf TYT Matematik', subjectId: math.id })
      renderBooks(services)

      expect(await screen.findByRole('link', { name: /Paraf TYT Matematik/ })).toBeInTheDocument()
      expect(screen.getByRole('heading', { name: 'Bir kitap seç' })).toBeInTheDocument()
    })

    it('liste ve detay yan yana; seçili satır işaretlenir', async () => {
      const book = await addBook({ title: 'Paraf TYT Matematik', subjectId: math.id })
      await addBook({ title: 'Diğer Kitap' })
      renderBooks(services, bookPath(book.id))

      expect(await screen.findByRole('heading', { name: `Detay ${book.id}` })).toBeInTheDocument()
      expect(screen.getByRole('heading', { level: 1, name: 'Kitaplar' })).toBeInTheDocument()
      expect(await screen.findByRole('link', { name: /Paraf TYT Matematik/ })).toHaveAttribute(
        'aria-current',
        'page',
      )
      expect(screen.getByRole('link', { name: /Diğer Kitap/ })).not.toHaveAttribute('aria-current')
      expect(screen.queryByRole('heading', { name: 'Bir kitap seç' })).not.toBeInTheDocument()
    })
  })
})
