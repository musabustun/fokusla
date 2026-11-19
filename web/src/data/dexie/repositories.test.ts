import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { NewEntity, TestResult, UUID } from '@/domain'
import type { Repositories } from '../repository'
import { createDatabase, type FokusDatabase } from './db'
import { createRepositories } from './repositories'

describe('specific repositories', () => {
  let db: FokusDatabase
  let repos: Repositories
  let clock: Date

  beforeEach(() => {
    db = createDatabase(crypto.randomUUID())
    clock = new Date('2026-11-19T07:00:00.000Z')
    repos = createRepositories(db, { now: () => clock, onChange: () => undefined })
  })

  afterEach(async () => {
    await db.delete()
  })

  it('profiles.getCurrent returns undefined, then the oldest active profile', async () => {
    expect(await repos.profiles.getCurrent()).toBeUndefined()
    const base = { displayName: null, appleUserId: null, targetExamYear: 2027 }
    const first = await repos.profiles.create({
      ...base,
      field: 'SAY',
      onboardingCompletedAt: null,
    })
    clock = new Date('2026-11-19T08:00:00.000Z')
    const second = await repos.profiles.create({
      ...base,
      field: 'EA',
      onboardingCompletedAt: null,
    })
    expect(await repos.profiles.getCurrent()).toEqual(first)
    await repos.profiles.delete(first.id)
    expect(await repos.profiles.getCurrent()).toEqual(second)
  })

  it('subjects.findByCatalogKey ignores deleted and unknown keys', async () => {
    const input = { name: 'Matematik', exam: 'TYT', fields: ['SAY'], order: 0 } as const
    const subject = await repos.subjects.create({
      ...input,
      fields: [...input.fields],
      catalogKey: 'tyt-matematik',
    })
    await repos.subjects.create({ ...input, fields: [], catalogKey: null })
    expect(await repos.subjects.findByCatalogKey('tyt-matematik')).toEqual(subject)
    expect(await repos.subjects.findByCatalogKey('yok')).toBeUndefined()
    await repos.subjects.delete(subject.id)
    expect(await repos.subjects.findByCatalogKey('tyt-matematik')).toBeUndefined()
  })

  it('topics.findBySubject filters by subject, sorts by order, excludes deleted', async () => {
    const make = (subjectId: UUID, order: number) =>
      repos.topics.create({ subjectId, name: `Konu ${order}`, catalogKey: null, order })
    const b = await make('s1', 2)
    const a = await make('s1', 1)
    const deleted = await make('s1', 0)
    await make('s2', 0)
    await repos.topics.delete(deleted.id)
    expect(await repos.topics.findBySubject('s1')).toEqual([a, b])
  })

  it('bookProgress.findByBook sorts by recordedAt', async () => {
    const make = (recordedAt: string, bookId = 'b1') =>
      repos.bookProgress.create({ bookId, reachedUnit: 1, topicId: null, recordedAt, note: null })
    const later = await make('2026-11-19T10:00:00.000Z')
    const earlier = await make('2026-11-18T10:00:00.000Z')
    await make('2026-11-17T10:00:00.000Z', 'b2')
    expect(await repos.bookProgress.findByBook('b1')).toEqual([earlier, later])
  })

  it('testResults.findBySubject / findByTopic sort by takenAt', async () => {
    const make = (takenAt: string, subjectId: UUID, topicId: UUID | null) => {
      const input: NewEntity<TestResult> = {
        subjectId,
        topicId,
        bookId: null,
        label: null,
        takenAt,
        correct: 10,
        wrong: 2,
        blank: 1,
        durationSeconds: null,
        note: null,
      }
      return repos.testResults.create(input)
    }
    const r2 = await make('2026-11-19T10:00:00.000Z', 's1', 't1')
    const r1 = await make('2026-11-18T10:00:00.000Z', 's1', null)
    const other = await make('2026-11-17T10:00:00.000Z', 's2', 't1')
    expect(await repos.testResults.findBySubject('s1')).toEqual([r1, r2])
    expect(await repos.testResults.findByTopic('t1')).toEqual([other, r2])
  })

  it('focusSessions.findActive returns the open, non-deleted session', async () => {
    const make = (startedAt: string, endedAt: string | null) =>
      repos.focusSessions.create({ subjectId: null, topicId: null, startedAt, endedAt, note: null })
    expect(await repos.focusSessions.findActive()).toBeUndefined()
    await make('2026-11-19T06:00:00.000Z', '2026-11-19T07:00:00.000Z')
    const deletedOpen = await make('2026-11-19T09:00:00.000Z', null)
    const open = await make('2026-11-19T08:00:00.000Z', null)
    await repos.focusSessions.delete(deletedOpen.id)
    expect(await repos.focusSessions.findActive()).toEqual(open)
  })

  it('focusSessions.findStartedBetween uses a half-open [from, to) range', async () => {
    const make = (startedAt: string) =>
      repos.focusSessions.create({
        subjectId: null,
        topicId: null,
        startedAt,
        endedAt: null,
        note: null,
      })
    const atFrom = await make('2026-11-19T00:00:00.000Z')
    const inside = await make('2026-11-19T12:00:00.000Z')
    await make('2026-11-20T00:00:00.000Z')
    await make('2026-11-18T23:59:59.999Z')
    const deleted = await make('2026-11-19T13:00:00.000Z')
    await repos.focusSessions.delete(deleted.id)
    const found = await repos.focusSessions.findStartedBetween(
      new Date('2026-11-19T00:00:00.000Z'),
      new Date('2026-11-20T00:00:00.000Z'),
    )
    expect(found).toEqual([atFrom, inside])
  })

  it('focusSegments.findBySession sorts by startedAt', async () => {
    const make = (sessionId: UUID, startedAt: string) =>
      repos.focusSegments.create({ sessionId, kind: 'focus', startedAt, endedAt: null })
    const second = await make('f1', '2026-11-19T08:30:00.000Z')
    const first = await make('f1', '2026-11-19T08:00:00.000Z')
    await make('f2', '2026-11-19T07:00:00.000Z')
    expect(await repos.focusSegments.findBySession('f1')).toEqual([first, second])
  })

  it('taskCompletions.findByDate / findByTask', async () => {
    const make = (taskId: UUID, date: string, completedAt: string) =>
      repos.taskCompletions.create({ taskId, date, completedAt })
    const a2 = await make('a', '2026-11-19', '2026-11-19T10:00:00.000Z')
    const b = await make('b', '2026-11-19', '2026-11-19T09:00:00.000Z')
    const a1 = await make('a', '2026-11-18', '2026-11-18T10:00:00.000Z')
    expect(await repos.taskCompletions.findByDate('2026-11-19')).toEqual([b, a2])
    expect(await repos.taskCompletions.findByTask('a')).toEqual([a1, a2])
    await repos.taskCompletions.delete(a2.id)
    expect(await repos.taskCompletions.findByTask('a')).toEqual([a1])
  })

  it('exposes plain repositories for the remaining entities', async () => {
    const task = await repos.tasks.create({
      title: 'Paragraf',
      kind: 'routine',
      notes: null,
      subjectId: null,
      dueDate: null,
      recurrence: { frequency: 'daily', weekdays: [] },
      completedAt: null,
      order: 0,
    })
    const friend = await repos.friends.create({
      remoteUserId: 'r1',
      displayName: 'Ayşe',
      status: 'pending',
    })
    const room = await repos.rooms.create({
      name: 'Oda',
      hostUserId: 'h',
      memberUserIds: [],
      inviteCode: 'ABC123',
      startedAt: null,
      endedAt: null,
    })
    expect(await repos.tasks.findAll()).toEqual([task])
    expect(await repos.friends.findAll()).toEqual([friend])
    expect(await repos.rooms.findAll()).toEqual([room])
    expect(await repos.books.findAll()).toEqual([])
  })
})
