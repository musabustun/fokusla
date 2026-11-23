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
      barcode: null,
      libraryKey: null,
      archivedAt: null,
    })

    expect(book.createdAt).toBe(now.toISOString())
    expect(services.sync.pendingChangeCount()).toBe(1)
    expect(services.sync.getState()).toEqual({ kind: 'disabled' })
    expect(await services.auth.getSession()).toBeNull()
  })

  it('works with no arguments (as main.tsx calls it)', () => {
    const services = createServices()
    expect(Object.keys(services.repositories)).toHaveLength(13)
  })
  it('wires the mock social service to the mock auth service', async () => {
    const services = createServices({
      dbName,
      authDelayMs: 0,
      social: { delayMs: 0, tickMs: 0, responseDelayMs: 0 },
    })
    expect(services.social.getSnapshot().status).toBe('loading')

    await services.auth.signInWithApple()
    await services.social.refresh()

    expect(services.social.getSnapshot().status).toBe('needsUsername')
  })
  it('includes the social mock data in local data export and delete-all', async () => {
    const services = createServices({
      dbName,
      authDelayMs: 0,
      syncDelayMs: 0,
      social: { delayMs: 0, tickMs: 0, responseDelayMs: 0 },
    })
    await services.auth.signInWithApple()
    await services.social.refresh()
    await services.social.claimUsername('ben.yks')

    const backup = await services.localData.exportAll()
    expect(JSON.stringify(backup.extras?.social)).toContain('ben.yks')

    await services.localData.deleteAll()
    const afterWipe = await services.localData.exportAll()
    expect(afterWipe.extras?.social).toEqual({ version: 1, accounts: {} })
    expect(services.social.getSnapshot().profile).toBeNull()
  })
})
