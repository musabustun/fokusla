import { Dexie } from 'dexie'
import { afterEach, describe, expect, it } from 'vitest'
import { createDatabase, type FokusDatabase } from './db'

describe('db schema v2 upgrade', () => {
  let name = ''
  let db: FokusDatabase | null = null

  afterEach(async () => {
    await db?.delete()
    db = null
  })

  it('fills barcode and libraryKey with null on books created under v1', async () => {
    name = crypto.randomUUID()
    const legacy = new Dexie(name)
    legacy.version(1).stores({ books: 'id, subjectId' })
    await legacy.table('books').add({
      id: 'b1',
      title: 'Eski kitap',
      deletedAt: null,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    })
    legacy.close()

    db = createDatabase(name)
    const book = await db.books.get('b1')
    expect(book?.barcode).toBeNull()
    expect(book?.libraryKey).toBeNull()
    expect(await db.bookSections.count()).toBe(0)
  })

  it('indexes books by barcode on a fresh database', async () => {
    db = createDatabase(crypto.randomUUID())
    expect(db.books.schema.idxByName).toHaveProperty('barcode')
    expect(db.bookSections.schema.idxByName).toHaveProperty('bookId')
  })
})
