import Dexie from 'dexie'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createServices } from './createServices'

describe('createServices', () => {
  const dbName = `fokus-test-${crypto.randomUUID()}`

  beforeEach(() => {
    localStorage.clear()
  })

  afterEach(async () => {
    await Dexie.delete(dbName)
  })

  it('wires repository writes into the sync queue using the injected clock', async () => {
    const now = new Date('2026-11-19T07:00:00.000Z')
    const services = createServices({ dbName, authDelayMs: 0, syncDelayMs: 0, now: () => now })

    const book = await services.repositories.books.create({
      title: 'Kitap',
      publisher: null,
      kind: 'other',
      subjectId: null,
      exam: null,
      unit: 'page',
      totalUnits: null,
      archivedAt: null,
    })

    expect(book.createdAt).toBe(now.toISOString())
    expect(services.sync.pendingChangeCount()).toBe(1)
    expect(services.sync.getState()).toEqual({ kind: 'disabled' })
    expect(await services.auth.getSession()).toBeNull()
  })

  it('works with no arguments (as main.tsx calls it)', () => {
    const services = createServices()
    expect(Object.keys(services.repositories)).toHaveLength(12)
  })
})
