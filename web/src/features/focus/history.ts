import type { FocusSegment, Subject, UUID } from '@/domain'
import { computeSessionStats } from '@/domain/calc/focus'
import { formatSessionStart } from './formatDate'
import type { FocusHistory } from './useFocusHistory'

export const HISTORY_LIMIT = 20
export const NO_SUBJECT_LABEL = 'Ders seçilmedi'

export interface HistoryRow {
  id: UUID
  title: string
  subtitle: string
  focusMs: number
}

function groupBySession(segments: readonly FocusSegment[]): Map<UUID, FocusSegment[]> {
  const groups = new Map<UUID, FocusSegment[]>()
  for (const segment of segments) {
    groups.set(segment.sessionId, [...(groups.get(segment.sessionId) ?? []), segment])
  }
  return groups
}

/** Son `limit` BİTMİŞ oturum, en yeni önce: ders adı, başlangıç (+ sınav/konu) ve odak süresi. */
export function buildHistoryRows(
  history: FocusHistory,
  now: Date,
  limit: number = HISTORY_LIMIT,
): HistoryRow[] {
  const segmentsBySession = groupBySession(history.segments)
  const subjectsById = new Map<UUID, Subject>(history.subjects.map((s) => [s.id, s]))
  return history.sessions
    .filter((session) => session.endedAt !== null)
    .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
    .slice(0, limit)
    .map((session) => {
      const subject = session.subjectId ? subjectsById.get(session.subjectId) : undefined
      const topic = session.topicId ? history.topicsById.get(session.topicId) : undefined
      const details = [subject?.exam, topic?.name].filter(Boolean)
      return {
        id: session.id,
        title: subject?.name ?? NO_SUBJECT_LABEL,
        subtitle: [formatSessionStart(new Date(session.startedAt)), ...details].join(' · '),
        focusMs: computeSessionStats(segmentsBySession.get(session.id) ?? [], now).focusMs,
      }
    })
}
