/**
 * Odak oturumu yazma işlemleri. Durum yalnızca Dexie'de yaşar (sayaç değeri saklanmaz);
 * süreler her zaman segment zaman damgalarından hesaplanır. `now` dışarıdan verilir.
 *
 * Değişmezler: aynı anda en fazla bir açık oturum; açık oturumda en fazla bir açık segment;
 * mola/devam geçişinde eski segment `now` anında kapanır, yenisi aynı `now` anında açılır.
 */
import type { Repositories } from '@/data'
import { findOpenSegment } from '@/domain/calc/focus'
import {
  toISODateTime,
  type FocusSegment,
  type FocusSegmentKind,
  type FocusSession,
  type UUID,
} from '@/domain'

export type FocusRepositories = Pick<Repositories, 'focusSessions' | 'focusSegments'>

export interface StartFocusInput {
  subjectId: UUID | null
  topicId: UUID | null
}

/** Yeni oturum + açık odak segmenti. Zaten açık oturum varsa onu döndürür (iki açık oturum olmaz). */
export async function startFocusSession(
  repositories: FocusRepositories,
  { subjectId, topicId }: StartFocusInput,
  now: Date,
): Promise<FocusSession> {
  const active = await repositories.focusSessions.findActive()
  if (active) return active

  const timestamp = toISODateTime(now)
  const session = await repositories.focusSessions.create({
    subjectId,
    topicId: subjectId === null ? null : topicId,
    startedAt: timestamp,
    endedAt: null,
    note: null,
  })
  await repositories.focusSegments.create({
    sessionId: session.id,
    kind: 'focus',
    startedAt: timestamp,
    endedAt: null,
  })
  return session
}

async function findOpenSession(
  repositories: FocusRepositories,
  sessionId: UUID,
): Promise<FocusSession | undefined> {
  const session = await repositories.focusSessions.findById(sessionId)
  return session && session.endedAt === null ? session : undefined
}

/** Açık segmentlerin hepsini `timestamp` anında kapatır (tutarsız veride birden fazla olabilir). */
async function closeOpenSegments(
  repositories: FocusRepositories,
  segments: readonly FocusSegment[],
  timestamp: string,
): Promise<void> {
  const open = segments.filter((segment) => segment.endedAt === null)
  await Promise.all(
    open.map((segment) => repositories.focusSegments.update(segment.id, { endedAt: timestamp })),
  )
}

async function switchSegment(
  repositories: FocusRepositories,
  sessionId: UUID,
  kind: FocusSegmentKind,
  now: Date,
): Promise<void> {
  if (!(await findOpenSession(repositories, sessionId))) return
  const segments = await repositories.focusSegments.findBySession(sessionId)
  if (findOpenSegment(segments)?.kind === kind) return

  const timestamp = toISODateTime(now)
  await closeOpenSegments(repositories, segments, timestamp)
  await repositories.focusSegments.create({ sessionId, kind, startedAt: timestamp, endedAt: null })
}

/** Odaktan molaya geçer. Zaten moladaysa ya da oturum kapalıysa bir şey yapmaz. */
export function pauseFocusSession(
  repositories: FocusRepositories,
  sessionId: UUID,
  now: Date,
): Promise<void> {
  return switchSegment(repositories, sessionId, 'break', now)
}

/** Moladan odağa döner. Zaten odaktaysa ya da oturum kapalıysa bir şey yapmaz. */
export function resumeFocusSession(
  repositories: FocusRepositories,
  sessionId: UUID,
  now: Date,
): Promise<void> {
  return switchSegment(repositories, sessionId, 'focus', now)
}

/**
 * Açık segmenti kapatır, sonra oturumun `endedAt` alanını set eder. Oturum yoksa undefined,
 * zaten bitmişse olduğu gibi döner.
 */
export async function finishFocusSession(
  repositories: FocusRepositories,
  sessionId: UUID,
  now: Date,
): Promise<FocusSession | undefined> {
  const session = await repositories.focusSessions.findById(sessionId)
  if (!session || session.endedAt !== null) return session

  const timestamp = toISODateTime(now)
  const segments = await repositories.focusSegments.findBySession(sessionId)
  await closeOpenSegments(repositories, segments, timestamp)
  return repositories.focusSessions.update(sessionId, { endedAt: timestamp })
}
