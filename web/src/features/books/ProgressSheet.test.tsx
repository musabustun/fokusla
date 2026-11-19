import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import type { Book, BookUnit } from '@/domain'
import { summarizeBook } from '@/domain/calc/books'
import { createTestServices, type TestServices } from '@/test/services'
import { addProgress, createBook } from './bookActions'
import { parseReachedUnit } from './progressInput'
import { ProgressSheet } from './ProgressSheet'

async function seedBook(
  services: AppServices,
  overrides: { unit?: BookUnit; totalUnits?: number | null } = {},
): Promise<Book> {
  return createBook(services.repositories, {
    title: 'Limit Matematik',
    publisher: null,
    kind: 'questionBank',
    subjectId: null,
    unit: overrides.unit ?? 'test',
    totalUnits: overrides.totalUnits === undefined ? 120 : overrides.totalUnits,
  })
}

async function renderSheet(services: AppServices, book: Book, onClose = vi.fn()) {
  const entries = await services.repositories.bookProgress.findByBook(book.id)
  const summary = summarizeBook(book, entries, new Date())
  render(
    <ServicesProvider services={services}>
      <ProgressSheet open onClose={onClose} summary={summary} />
    </ServicesProvider>,
  )
  return { onClose, user: userEvent.setup() }
}

describe('parseReachedUnit', () => {
  it.each([
    ['34', 34],
    [' 7 ', 7],
    ['0', 0],
    ['', null],
    ['   ', null],
    ['-3', null],
    ['2.5', null],
    ['abc', null],
    ['99999999999999999999', null],
  ])('"%s" → %s', (raw, expected) => {
    expect(parseReachedUnit(raw)).toBe(expected)
  })
})

describe('ProgressSheet', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('başlık, açıklama, birime göre etiket ve toplam ipucu gösterir', async () => {
    const book = await seedBook(services)
    await renderSheet(services, book)

    expect(screen.getByRole('dialog', { name: 'İlerleme gir' })).toHaveAccessibleDescription(
      'Nereye kadar geldin?',
    )
    const input = screen.getByLabelText('Ulaştığın test')
    expect(input).toHaveValue(null)
    expect(input).toHaveAccessibleDescription('Toplam: 120')
    expect(screen.getByLabelText('Not')).toBeInTheDocument()
  })

  it('mevcut konumla doldurulur; toplam bilinmiyorsa ipucu yoktur', async () => {
    const book = await seedBook(services, { unit: 'page', totalUnits: null })
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 210, note: null })
    await renderSheet(services, book)

    const input = screen.getByLabelText('Ulaştığın sayfa')
    expect(input).toHaveValue(210)
    expect(input).not.toHaveAccessibleDescription()
  })

  it('açılınca sayı alanını odaklar', async () => {
    const book = await seedBook(services, { unit: 'section' })
    await renderSheet(services, book)
    const input = screen.getByLabelText('Ulaştığın bölüm')
    await vi.waitFor(() => expect(input).toHaveFocus())
  })

  it('boş girdiyle kaydetmez ve hata gösterir', async () => {
    const book = await seedBook(services)
    const { user, onClose } = await renderSheet(services, book)

    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Geçerli bir sayı gir.')
    expect(screen.getByLabelText('Ulaştığın test')).toHaveAttribute('aria-invalid', 'true')
    expect(onClose).not.toHaveBeenCalled()
    expect(await services.repositories.bookProgress.findByBook(book.id)).toHaveLength(0)
  })

  it('geriye giden ve toplama ulaşan değerler için uyarır', async () => {
    const book = await seedBook(services)
    await addProgress(services.repositories, { bookId: book.id, reachedUnit: 40, note: null })
    const { user } = await renderSheet(services, book)
    const input = screen.getByLabelText('Ulaştığın test')

    await user.clear(input)
    await user.type(input, '30')
    expect(
      screen.getByText('Önceki kayıttan geride; düzeltme olarak kaydedilir.'),
    ).toBeInTheDocument()
    expect(screen.queryByText('Kitap tamamlandı olarak işaretlenecek.')).not.toBeInTheDocument()

    await user.clear(input)
    await user.type(input, '120')
    expect(screen.getByText('Kitap tamamlandı olarak işaretlenecek.')).toBeInTheDocument()
    expect(
      screen.queryByText('Önceki kayıttan geride; düzeltme olarak kaydedilir.'),
    ).not.toBeInTheDocument()
  })

  it('Enter ile konumu ve notu kaydeder, sonra kapanır', async () => {
    const book = await seedBook(services)
    const { user, onClose } = await renderSheet(services, book)

    await user.type(screen.getByLabelText('Not'), '  Türev bitti  ')
    await user.type(screen.getByLabelText('Ulaştığın test'), '34{Enter}')

    await vi.waitFor(() => expect(onClose).toHaveBeenCalledTimes(1))
    const [entry] = await services.repositories.bookProgress.findByBook(book.id)
    expect(entry).toMatchObject({ bookId: book.id, reachedUnit: 34, note: 'Türev bitti' })
  })

  it('beklenmeyen hatada kullanıcıya mesaj gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.bookProgress, 'create').mockRejectedValue(new Error('disk'))
    const book = await seedBook(services)
    const { user, onClose } = await renderSheet(services, book)

    await user.type(screen.getByLabelText('Ulaştığın test'), '5')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Kaydedilemedi')
    expect(onClose).not.toHaveBeenCalled()
  })
})
