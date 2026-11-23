import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createDatabase, type FokusDatabase } from './db'
import { createRepositories } from './repositories'
import { DexieLocalDataService } from './DexieLocalDataService'
import type { Repositories } from '../repository'

const NOW = new Date('2026-11-19T10:00:00.000Z')

describe('DexieLocalDataService', () => {
  let db: FokusDatabase
  let repositories: Repositories
  let service: DexieLocalDataService

  beforeEach(() => {
    db = createDatabase(`test-${crypto.randomUUID()}`)
    repositories = createRepositories(db, { now: () => NOW, onChange: () => undefined })
    service = new DexieLocalDataService(db, () => NOW)
  })

  afterEach(async () => {
    await db.delete()
  })

  it('exports an empty but well-formed backup', async () => {
    const backup = await service.exportAll()
    expect(backup.app).toBe('fokus')
    expect(backup.formatVersion).toBe(1)
    expect(backup.exportedAt).toBe('2026-11-19T10:00:00.000Z')
    expect(Object.keys(backup.entities).sort()).toEqual(
      [
        'bookProgress',
        'bookSections',
        'books',
        'focusSegments',
        'focusSessions',
        'friends',
        'profiles',
        'rooms',
        'subjects',
        'taskCompletions',
        'tasks',
        'testResults',
        'topics',
      ].sort(),
    )
    for (const rows of Object.values(backup.entities)) expect(rows).toEqual([])
  })

  it('exports live records and leaves soft-deleted ones out', async () => {
    const kept = await repositories.books.create({
      title: 'Kalsın',
      publisher: null,
      kind: 'questionBank',
      subjectId: null,
      exam: null,
      unit: 'page',
      totalUnits: 100,
      barcode: null,
      libraryKey: null,
      archivedAt: null,
    })
    const removed = await repositories.books.create({
      title: 'Silinen',
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
    await repositories.books.delete(removed.id)

    const backup = await service.exportAll()
    expect(backup.entities.books).toEqual([kept])
    // JSON'a çevrilebilir ve geri okunabilir.
    expect(JSON.parse(JSON.stringify(backup))).toEqual(backup)
  })

  it('permanently deletes every table, tombstones included', async () => {
    const profile = await repositories.profiles.create({
      displayName: 'Ayşe',
      field: 'SAY',
      appleUserId: null,
      targetExamYear: null,
      onboardingCompletedAt: null,
    })
    await repositories.profiles.delete(profile.id)
    await repositories.subjects.create({
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY'],
      catalogKey: null,
      order: 0,
    })

    await service.deleteAll()

    for (const table of db.tables) expect(await table.count()).toBe(0)
  })
})
