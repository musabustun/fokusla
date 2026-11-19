import { render, screen, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import { toISODate, toISODateTime, type Book } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { BooksCard } from './BooksCard'

function renderCard(services: AppServices) {
  const router = createMemoryRouter(
    [
      { path: ROUTES.today, element: <BooksCard today={toISODate(new Date())} /> },
      { path: ROUTES.books, element: <h1>Kitaplar</h1> },
    ],
    { initialEntries: [ROUTES.today] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return router
}

const card = () => screen.getByRole('region', { name: 'Kitaplar' })

describe('BooksCard', () => {
  let ctx: TestServices
  let services: AppServices

  const addBook = (patch: Partial<Book> & Pick<Book, 'title'>) =>
    services.repositories.books.create({
      publisher: null,
      kind: 'questionBank',
      subjectId: null,
      exam: null,
      unit: 'test',
      totalUnits: null,
      archivedAt: null,
      ...patch,
    })

  const addProgress = (book: Book, reachedUnit: number) =>
    services.repositories.bookProgress.create({
      bookId: book.id,
      reachedUnit,
      topicId: null,
      recordedAt: toISODateTime(new Date()),
      note: null,
    })

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('devam eden kitap yoksa boş durumu gösterir', async () => {
    const finished = await addBook({ title: 'Biten Kitap', totalUnits: 10 })
    await addProgress(finished, 10)
    await addBook({ title: 'Arşivdeki', archivedAt: toISODateTime(new Date()) })
    renderCard(services)

    const link = await within(card()).findByRole('link', { name: 'Kitap ekle' })
    expect(link).toHaveAttribute('href', ROUTES.books)
    expect(within(card()).getByText('Devam eden kitabın yok.')).toBeVisible()
    expect(within(card()).queryByText('Biten Kitap')).toBeNull()
  })

  it('ilerlemeyi birimiyle, yüzdeyle ve ilerleme çubuğuyla gösterir', async () => {
    const tests = await addBook({ title: 'Paraf TYT Matematik', unit: 'test', totalUnits: 40 })
    await addProgress(tests, 10)
    const pages = await addBook({ title: 'Konu Anlatımı', unit: 'page', totalUnits: null })
    await addProgress(pages, 120)
    renderCard(services)

    const bar = await within(card()).findByRole('progressbar', {
      name: 'Paraf TYT Matematik ilerlemesi',
    })
    expect(bar).toHaveAttribute('aria-valuenow', '25')
    expect(within(card()).getByText('10 / 40 test')).toBeVisible()
    expect(within(card()).getByText('%25')).toBeVisible()
    // Toplamı bilinmeyen kitap: yalnızca konum, yüzde ve çubuk yok.
    expect(within(card()).getByText('120. sayfa')).toBeVisible()
    expect(within(card()).getAllByRole('progressbar')).toHaveLength(1)
    expect(within(card()).getByRole('link', { name: 'Tüm kitaplar' })).toHaveAttribute(
      'href',
      ROUTES.books,
    )
  })

  it('en fazla 3 kitap gösterir; önce devam edenler', async () => {
    await addBook({ title: 'Başlanmamış', unit: 'section', totalUnits: 12 })
    for (const title of ['Bir', 'İki', 'Üç']) {
      const book = await addBook({ title, totalUnits: 20 })
      await addProgress(book, 5)
    }
    renderCard(services)

    await within(card()).findByText('Bir')
    expect(within(card()).getAllByRole('listitem')).toHaveLength(3)
    expect(within(card()).queryByText('Başlanmamış')).toBeNull()
  })

  it('başlanmamış kitabı 0 ilerlemeyle gösterir', async () => {
    await addBook({ title: 'Yeni Deneme', unit: 'section', totalUnits: 12 })
    await addBook({ title: 'Toplamsız', unit: 'page', totalUnits: null })
    renderCard(services)

    expect(await within(card()).findByText('0 / 12 bölüm')).toBeVisible()
    expect(within(card()).getByText('Başlanmadı')).toBeVisible()
    expect(
      within(card()).getByRole('progressbar', { name: 'Yeni Deneme ilerlemesi' }),
    ).toHaveAttribute('aria-valuenow', '0')
  })
})
