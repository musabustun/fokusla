import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { Curriculum } from '@/curriculum'
import { createDatabase, type FokusDatabase } from '../dexie/db'
import { createRepositories } from '../dexie/repositories'
import type { Repositories } from '../repository'
import { catalogEntityId } from '@/domain'
import { ensureCurriculumSeeded } from './ensureCurriculumSeeded'

const FIXTURE: Curriculum = {
  examYear: 2026,
  sources: ['test'],
  verifiedAt: '2026-11-19',
  subjects: [
    {
      key: 'tyt-matematik',
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY', 'EA', 'SOZ', 'DIL'],
      questionCount: 40,
      topics: [
        { key: 'tyt-matematik.temel-kavramlar', name: 'Temel Kavramlar' },
        { key: 'tyt-matematik.sayi-basamaklari', name: 'Sayı Basamakları' },
      ],
    },
    {
      key: 'ayt-fizik',
      name: 'Fizik',
      exam: 'AYT',
      fields: ['SAY'],
      questionCount: 14,
      topics: [{ key: 'ayt-fizik.vektorler', name: 'Vektörler' }],
    },
  ],
}

describe('ensureCurriculumSeeded', () => {
  let db: FokusDatabase
  let repos: Repositories

  beforeEach(() => {
    db = createDatabase(crypto.randomUUID())
    repos = createRepositories(db, { now: () => new Date(), onChange: () => undefined })
  })

  afterEach(async () => {
    await db.delete()
  })

  it('creates subjects and topics in catalog order', async () => {
    const result = await ensureCurriculumSeeded(repos, FIXTURE)
    expect(result).toEqual({ subjectsCreated: 2, topicsCreated: 3 })

    const math = await repos.subjects.findByCatalogKey('tyt-matematik')
    const physics = await repos.subjects.findByCatalogKey('ayt-fizik')
    expect(math).toMatchObject({ name: 'Matematik', exam: 'TYT', order: 0 })
    expect(physics).toMatchObject({ fields: ['SAY'], order: 1 })
    const topics = await repos.topics.findBySubject(math?.id ?? '')
    expect(topics.map((t) => [t.catalogKey, t.order])).toEqual([
      ['tyt-matematik.temel-kavramlar', 0],
      ['tyt-matematik.sayi-basamaklari', 1],
    ])
  })

  it('uses deterministic ids derived from catalogKey (same on every device)', async () => {
    await ensureCurriculumSeeded(repos, FIXTURE)
    const math = await repos.subjects.findByCatalogKey('tyt-matematik')
    expect(math?.id).toBe(await catalogEntityId('tyt-matematik'))
    const [firstTopic] = await repos.topics.findBySubject(math?.id ?? '')
    expect(firstTopic?.id).toBe(await catalogEntityId('tyt-matematik.temel-kavramlar'))

    const otherDb = createDatabase(crypto.randomUUID())
    const otherRepos = createRepositories(otherDb, {
      now: () => new Date(),
      onChange: () => undefined,
    })
    await ensureCurriculumSeeded(otherRepos, FIXTURE)
    const otherMath = await otherRepos.subjects.findByCatalogKey('tyt-matematik')
    expect(otherMath?.id).toBe(math?.id)
    await otherDb.delete()
  })

  it('is idempotent: a second run creates nothing', async () => {
    await ensureCurriculumSeeded(repos, FIXTURE)
    expect(await ensureCurriculumSeeded(repos, FIXTURE)).toEqual({
      subjectsCreated: 0,
      topicsCreated: 0,
    })
    expect(await repos.subjects.findAll()).toHaveLength(2)
    expect(await repos.topics.findAll()).toHaveLength(3)
  })

  it('adds only topics that are new in the catalog', async () => {
    await ensureCurriculumSeeded(repos, FIXTURE)
    const [math, physics] = FIXTURE.subjects
    if (!math || !physics) throw new Error('fixture')
    const extended: Curriculum = {
      ...FIXTURE,
      subjects: [
        { ...math, topics: [...math.topics, { key: 'tyt-matematik.oran', name: 'Oran' }] },
        physics,
      ],
    }
    expect(await ensureCurriculumSeeded(repos, extended)).toEqual({
      subjectsCreated: 0,
      topicsCreated: 1,
    })
  })

  it('collapses concurrent calls into a single seeding run', async () => {
    const [a, b] = await Promise.all([
      ensureCurriculumSeeded(repos, FIXTURE),
      ensureCurriculumSeeded(repos, FIXTURE),
    ])
    expect(a).toEqual(b)
    expect(await repos.subjects.findAll()).toHaveLength(2)
  })
})
