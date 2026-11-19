/**
 * Odak istatistikleri ve geçmiş için tüm oturumlar/segmentler + ders/konu adları.
 * Prototip için tümünü okumak yeterli; native sürümde tarih aralığıyla sınırlanacak.
 */
import { useLiveData, useServices } from '@/data'
import type { FocusSegment, FocusSession, Subject, Topic, UUID } from '@/domain'

export interface FocusHistory {
  sessions: FocusSession[]
  segments: FocusSegment[]
  subjects: Subject[]
  topicsById: ReadonlyMap<UUID, Topic>
}

export function useFocusHistory(): FocusHistory | undefined {
  const { repositories } = useServices()
  return useLiveData(async (): Promise<FocusHistory> => {
    const [sessions, segments, subjects] = await Promise.all([
      repositories.focusSessions.findAll(),
      repositories.focusSegments.findAll(),
      repositories.subjects.findAll(),
    ])
    const topicIds = [...new Set(sessions.flatMap((s) => (s.topicId ? [s.topicId] : [])))]
    const topics = await Promise.all(topicIds.map((id) => repositories.topics.findById(id)))
    const topicsById = new Map(
      topics.flatMap((topic): [UUID, Topic][] => (topic ? [[topic.id, topic]] : [])),
    )
    return { sessions, segments, subjects, topicsById }
  }, [repositories])
}
