import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createTestServices, type TestServices } from '@/test/services'
import {
  BookValidationError,
  createBook,
  deleteBook,
  updateBook,
  type BookInput,
} from './bookActions'

const BASE: BookInput = {
  title: 'Kitap',
  publisher: null,
  kind: 'questionBank',
  subjectId: null,
  unit: 'test',
  totalUnits: 10,
}

describe('bookActions barkod ve bölümler', () => {
  let ctx: TestServices
  beforeEach(() => {
    ctx = createTestServices()
  })
  afterEach(async () => {
    await ctx.dispose()
  })
  const repos = () => ctx.services.repositories

  it('barkodsuz çağrı eskisi gibi null yazar', async () => {
    const book = await createBook(repos(), BASE)
    expect(book).toMatchObject({ barcode: null, libraryKey: null })
  })

  it('barkodu normalize eder (ISBN-10, tire), boşu null yapar', async () => {
    const a = await createBook(repos(), { ...BASE, barcode: '0-306-40615-2' })
    const b = await createBook(repos(), { ...BASE, barcode: '  ' })
    expect(a.barcode).toBe('9780306406157')
    expect(b.barcode).toBeNull()
  })

  it('geçersiz barkodu reddeder', async () => {
    await expect(createBook(repos(), { ...BASE, barcode: '123' })).rejects.toBeInstanceOf(
      BookValidationError,
    )
    expect(await repos().books.findAll()).toHaveLength(0)
  })

  it('libraryKey ve bölümleri yazar; girdiyi mutasyona uğratmaz', async () => {
    const sections = [{ title: 'A', order: 1, startUnit: 1, endUnit: 5, topicId: null }]
    const input: BookInput = { ...BASE, libraryKey: 'k', sections }
    const snapshot = structuredClone(input)

    const book = await createBook(repos(), input)

    expect(input).toEqual(snapshot)
    expect(book.libraryKey).toBe('k')
    expect(await repos().bookSections.findByBook(book.id)).toMatchObject([
      { title: 'A', order: 1, bookId: book.id },
    ])
  })

  it('güncellemede barkod verilmezse korunur, verilirse değişir, null silinir', async () => {
    const book = await createBook(repos(), { ...BASE, barcode: '9780306406157', libraryKey: 'k' })

    const same = await updateBook(repos(), book.id, { ...BASE, title: 'Yeni' })
    expect(same).toMatchObject({ barcode: '9780306406157', libraryKey: 'k', title: 'Yeni' })

    const cleared = await updateBook(repos(), book.id, { ...BASE, barcode: null })
    expect(cleared.barcode).toBeNull()
  })

  it('kitap silinince bölümleri de silinir', async () => {
    const book = await createBook(repos(), {
      ...BASE,
      sections: [{ title: 'A', order: 1, startUnit: null, endUnit: null, topicId: null }],
    })
    await deleteBook(repos(), book.id)
    expect(await repos().bookSections.findByBook(book.id)).toHaveLength(0)
  })
})
