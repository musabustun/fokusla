/** Analiz ekranlarının tek veri kaynağı: profil, dersler, konular, testler, kitaplar + özetler. */
import { useMemo } from 'react'
import { useCurrentProfile, useLiveData, useServices } from '@/data'
import type { Book, Subject, TestResult, Topic, UUID, YksField } from '@/domain'
import { summarizeBySubject, summarizeByTopic, type TestSummary } from '@/domain/calc/tests'
import { visibleSubjects } from './subjects'

export interface AnalysisData {
  status: 'ready'
  field: YksField
  /** Kullanıcının alanında görünen dersler (sınav → sıra → ad). */
  subjects: Subject[]
  subjectsById: ReadonlyMap<UUID, Subject>
  /** Görünen derslerin konuları, `order`'a göre sıralı. */
  topicsBySubject: ReadonlyMap<UUID, Topic[]>
  topicsById: ReadonlyMap<UUID, Topic>
  /** Yalnızca görünen derslere ait sonuçlar. */
  results: TestResult[]
  booksById: ReadonlyMap<UUID, Book>
  subjectSummaries: ReadonlyMap<UUID, TestSummary>
  topicSummaries: ReadonlyMap<UUID, TestSummary>
}

export type AnalysisDataState = { status: 'loading' } | AnalysisData

const LOADING: AnalysisDataState = { status: 'loading' }

/** Profil yoksa (onboarding kapısı normalde engeller) varsayılan alan. */
const FALLBACK_FIELD: YksField = 'SAY'

interface RawData {
  subjects: Subject[]
  topics: Topic[]
  results: TestResult[]
  books: Book[]
}

function groupTopics(topics: readonly Topic[], subjectIds: ReadonlySet<UUID>) {
  const bySubject = new Map<UUID, Topic[]>()
  for (const topic of topics) {
    if (!subjectIds.has(topic.subjectId)) continue
    bySubject.set(topic.subjectId, [...(bySubject.get(topic.subjectId) ?? []), topic])
  }
  for (const [subjectId, list] of bySubject) {
    bySubject.set(
      subjectId,
      list.toSorted((a, b) => a.order - b.order || a.name.localeCompare(b.name, 'tr-TR')),
    )
  }
  return bySubject
}

export function buildAnalysisData(raw: RawData, field: YksField): AnalysisData {
  const subjects = visibleSubjects(raw.subjects, field)
  const subjectIds = new Set(subjects.map((s) => s.id))
  const topicsBySubject = groupTopics(raw.topics, subjectIds)
  const topicsById = new Map([...topicsBySubject.values()].flat().map((t) => [t.id, t]))
  const results = raw.results.filter((r) => subjectIds.has(r.subjectId))
  return {
    status: 'ready',
    field,
    subjects,
    subjectsById: new Map(subjects.map((s) => [s.id, s])),
    topicsBySubject,
    topicsById,
    results,
    booksById: new Map(raw.books.map((b) => [b.id, b])),
    subjectSummaries: summarizeBySubject(results),
    topicSummaries: summarizeByTopic(results.filter((r) => r.topicId && topicsById.has(r.topicId))),
  }
}

export function useAnalysisData(): AnalysisDataState {
  const { repositories } = useServices()
  const profileState = useCurrentProfile()
  const raw = useLiveData(async (): Promise<RawData> => {
    const [subjects, topics, results, books] = await Promise.all([
      repositories.subjects.findAll(),
      repositories.topics.findAll(),
      repositories.testResults.findAll(),
      repositories.books.findAll(),
    ])
    return { subjects, topics, results, books }
  }, [repositories])

  const field =
    profileState.status === 'ready' ? (profileState.profile?.field ?? FALLBACK_FIELD) : null

  return useMemo(() => {
    if (!raw || !field) return LOADING
    return buildAnalysisData(raw, field)
  }, [raw, field])
}
