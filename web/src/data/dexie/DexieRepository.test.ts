import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { Book, NewEntity } from '@/domain'
import { EntityNotFoundError } from '../repository'
import type { LocalChange } from '../sync/SyncService'
import { createDatabase, type FokusDatabase } from './db'
import { DexieRepository } from './DexieRepository'

const T0 = '2026-11-19T07:00:00.000Z'
const T1 = '2026-11-19T08:00:00.000Z'

const bookInput = (): NewEntity<Book> => ({
  title: 'Paraf TYT Matematik',
  publisher: 'Paraf',
  kind: 'questionBank',
  subjectId: null,
  exam: 'TYT',
  unit: 'test',
  totalUnits: 120,
  archivedAt: null,
})

describe('DexieRepository', () => {
  let db: FokusDatabase
  let clock: Date
  let changes: LocalChange[]
  let repo: DexieRepository<Book>

  beforeEach(() => {
    db = createDatabase(crypto.randomUUID())
    clock = new Date(T0)
    changes = []
    repo = new DexieRepository(db.books, 'books', {
      now: () => clock,
      onChange: (change) => changes.push(change),
    })
  })

  afterEach(async () => {
    await db.delete()
  })

  it('create fills id, timestamps and deletedAt without mutating input', async () => {
    const input = bookInput()
    const snapshot = structuredClone(input)

    const book = await repo.create(input)

    expect(book.id).toMatch(/^[0-9a-f-]{36}$/)
    expect(book).toMatchObject({ ...snapshot, createdAt: T0, updatedAt: T0, deletedAt: null })
    expect(input).toEqual(snapshot)
    expect(book).not.toBe(input)
    expect(await repo.findById(book.id)).toEqual(book)
  })

  it('create ignores base fields smuggled into the input at runtime', async () => {
    const smuggled = { ...bookInput(), id: 'x', deletedAt: T1 } as NewEntity<Book>
    const book = await repo.create(smuggled)
    expect(book.id).not.toBe('x')
    expect(book.deletedAt).toBeNull()
  })

  it('update refreshes updatedAt, keeps base fields and returns a new object', async () => {
    const book = await repo.create(bookInput())
    clock = new Date(T1)
    const patch = { title: 'Yeni ad', id: 'hack', createdAt: 'hack' } as Partial<Book>

    const updated = await repo.update(book.id, patch)

    expect(updated).toEqual({ ...book, title: 'Yeni ad', updatedAt: T1 })
    expect(updated).not.toBe(book)
    expect(book.title).toBe('Paraf TYT Matematik')
    expect(await repo.findById(book.id)).toEqual(updated)
  })

  it('update throws EntityNotFoundError for missing and deleted ids', async () => {
    await expect(repo.update('missing', { title: 'x' })).rejects.toBeInstanceOf(EntityNotFoundError)
    const book = await repo.create(bookInput())
    await repo.delete(book.id)
    await expect(repo.update(book.id, { title: 'x' })).rejects.toThrow('Kitap bulunamadı')
  })

  it('delete is soft and excluded from reads unless includeDeleted', async () => {
    const kept = await repo.create(bookInput())
    const removed = await repo.create(bookInput())
    clock = new Date(T1)

    await repo.delete(removed.id)

    expect(await repo.findAll()).toEqual([kept])
    expect(await repo.findById(removed.id)).toBeUndefined()
    const tombstone = await repo.findById(removed.id, { includeDeleted: true })
    expect(tombstone).toMatchObject({ deletedAt: T1, updatedAt: T1 })
    expect(await repo.findAll({ includeDeleted: true })).toHaveLength(2)
  })

  it('delete throws for missing or already deleted ids', async () => {
    await expect(repo.delete('missing')).rejects.toBeInstanceOf(EntityNotFoundError)
    const book = await repo.create(bookInput())
    await repo.delete(book.id)
    await expect(repo.delete(book.id)).rejects.toBeInstanceOf(EntityNotFoundError)
  })

  it('reports each successful write via onChange with the right op', async () => {
    const book = await repo.create(bookInput())
    clock = new Date(T1)
    await repo.update(book.id, { title: 'x' })
    await repo.delete(book.id)
    await repo.update('missing', { title: 'y' }).catch(() => undefined)

    expect(changes).toEqual([
      { entity: 'books', id: book.id, op: 'upsert', at: T0 },
      { entity: 'books', id: book.id, op: 'upsert', at: T1 },
      { entity: 'books', id: book.id, op: 'delete', at: T1 },
    ])
  })

  it('does not report a change when the write fails', async () => {
    const onChange = vi.fn()
    const failing = new DexieRepository(db.books, 'books', { now: () => clock, onChange })
    await failing.delete('missing').catch(() => undefined)
    expect(onChange).not.toHaveBeenCalled()
  })
})
