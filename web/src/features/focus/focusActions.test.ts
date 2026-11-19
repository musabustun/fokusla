import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { Repositories } from '@/data'
import { createTestServices, type TestServices } from '@/test/services'
import {
  finishFocusSession,
  pauseFocusSession,
  resumeFocusSession,
  startFocusSession,
} from './focusActions'

const T0 = new Date('2026-11-19T07:00:00.000Z')
const at = (minutes: number) => new Date(T0.getTime() + minutes * 60_000)
const NO_SUBJECT = { subjectId: null, topicId: null }

describe('focusActions', () => {
  let ctx: TestServices
  let repos: Repositories

  beforeEach(() => {
    ctx = createTestServices()
    repos = ctx.services.repositories
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  const segmentsOf = async (sessionId: string) =>
    (await repos.focusSegments.findBySession(sessionId)).sort((a, b) =>
      a.startedAt.localeCompare(b.startedAt),
    )

  it('start creates an open session with an open focus segment', async () => {
    const session = await startFocusSession(repos, { subjectId: 's1', topicId: 't1' }, T0)

    expect(session).toMatchObject({
      subjectId: 's1',
      topicId: 't1',
      startedAt: T0.toISOString(),
      endedAt: null,
    })
    expect(await repos.focusSessions.findActive()).toEqual(session)
    expect(await segmentsOf(session.id)).toMatchObject([
      { kind: 'focus', startedAt: T0.toISOString(), endedAt: null },
    ])
  })

  it('drops the topic when no subject is chosen', async () => {
    const session = await startFocusSession(repos, { subjectId: null, topicId: 't1' }, T0)
    expect(session.topicId).toBeNull()
  })

  it('a second start returns the active session instead of opening another', async () => {
    const first = await startFocusSession(repos, NO_SUBJECT, T0)
    const second = await startFocusSession(repos, { subjectId: 's1', topicId: null }, at(5))

    expect(second.id).toBe(first.id)
    expect(await repos.focusSessions.findAll()).toHaveLength(1)
    expect(await segmentsOf(first.id)).toHaveLength(1)
  })

  it('pause and resume close the open segment and open the next at the same instant', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    await pauseFocusSession(repos, session.id, at(25))
    await resumeFocusSession(repos, session.id, at(30))

    expect(await segmentsOf(session.id)).toMatchObject([
      { kind: 'focus', startedAt: T0.toISOString(), endedAt: at(25).toISOString() },
      { kind: 'break', startedAt: at(25).toISOString(), endedAt: at(30).toISOString() },
      { kind: 'focus', startedAt: at(30).toISOString(), endedAt: null },
    ])
  })

  it('pause while on break and resume while focusing are no-ops', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    await resumeFocusSession(repos, session.id, at(1))
    expect(await segmentsOf(session.id)).toHaveLength(1)

    await pauseFocusSession(repos, session.id, at(2))
    await pauseFocusSession(repos, session.id, at(3))
    expect(await segmentsOf(session.id)).toMatchObject([
      { kind: 'focus', endedAt: at(2).toISOString() },
      { kind: 'break', startedAt: at(2).toISOString(), endedAt: null },
    ])
  })

  it('pause and resume do nothing for an ended or unknown session', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    await finishFocusSession(repos, session.id, at(10))
    await pauseFocusSession(repos, session.id, at(11))
    await resumeFocusSession(repos, 'missing', at(12))

    expect(await segmentsOf(session.id)).toHaveLength(1)
    expect(await repos.focusSegments.findAll()).toHaveLength(1)
  })

  it('finish closes the open focus segment and sets endedAt', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    const finished = await finishFocusSession(repos, session.id, at(40))

    expect(finished).toMatchObject({ id: session.id, endedAt: at(40).toISOString() })
    expect(await repos.focusSessions.findActive()).toBeUndefined()
    expect(await segmentsOf(session.id)).toMatchObject([
      { kind: 'focus', endedAt: at(40).toISOString() },
    ])
  })

  it('finish from a break closes the break segment', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    await pauseFocusSession(repos, session.id, at(20))
    await finishFocusSession(repos, session.id, at(51))

    expect(await segmentsOf(session.id)).toMatchObject([
      { kind: 'focus', endedAt: at(20).toISOString() },
      { kind: 'break', startedAt: at(20).toISOString(), endedAt: at(51).toISOString() },
    ])
  })

  it('finish is idempotent and tolerates unknown sessions', async () => {
    const session = await startFocusSession(repos, NO_SUBJECT, T0)
    await finishFocusSession(repos, session.id, at(10))
    const again = await finishFocusSession(repos, session.id, at(20))

    expect(again?.endedAt).toBe(at(10).toISOString())
    expect(await finishFocusSession(repos, 'missing', at(20))).toBeUndefined()
  })

  it('a new session can start after the previous one finished', async () => {
    const first = await startFocusSession(repos, NO_SUBJECT, T0)
    await finishFocusSession(repos, first.id, at(10))
    const second = await startFocusSession(repos, NO_SUBJECT, at(15))

    expect(second.id).not.toBe(first.id)
    expect(await repos.focusSessions.findActive()).toEqual(second)
  })
})
