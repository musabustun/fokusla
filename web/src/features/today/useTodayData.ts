/**
 * Bugün ekranının veri hook'ları. Diğer modüllerin varlıklarını @/data repository'leri üzerinden
 * YALNIZCA OKUR (yazma yalnızca görev tamamlama eyleminde, bkz. taskActions.ts).
 * Her hook yüklenirken `undefined` döner; tablolar değişince canlı güncellenir.
 */
import { useLiveData, useServices } from '@/data'
import type {
  Book,
  BookProgress,
  FocusSegment,
  FocusSession,
  ISODate,
  Task,
  TaskCompletion,
  TestResult,
  UUID,
} from '@/domain'
import { localDayBounds } from '@/domain/calc/focus'
import { addDays } from '@/domain/calc/tasks'
import { TODAY_CHART_DAYS } from '@/domain/calc/today'

export interface TodayFocusData {
  /** Grafik penceresine (son 7 gün + gece yarısını aşan bir önceki gün) dokunan oturumlar + açık oturum. */
  sessions: FocusSession[]
  /** Bu oturumların segmentleri. */
  segments: FocusSegment[]
  /** Açık oturum (endedAt === null); yoksa undefined. */
  activeSession: FocusSession | undefined
}

/** Odak kartı verisi: son 7 günün oturumları/segmentleri ve açık oturum. */
export function useTodayFocusData(today: ISODate): TodayFocusData | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    // Gece yarısını aşan oturumlar için pencereden bir gün önce başlayanlar da okunur.
    const from = localDayBounds(addDays(today, -TODAY_CHART_DAYS)).start
    const to = localDayBounds(today).end
    const [activeSession, recent] = await Promise.all([
      repositories.focusSessions.findActive(),
      repositories.focusSessions.findStartedBetween(from, to),
    ])
    const sessions =
      activeSession && !recent.some((s) => s.id === activeSession.id)
        ? [...recent, activeSession]
        : recent
    const segmentLists = await Promise.all(
      sessions.map((session) => repositories.focusSegments.findBySession(session.id)),
    )
    return { sessions, segments: segmentLists.flat(), activeSession }
  }, [repositories, today])
}

export interface TodayTasksData {
  tasks: Task[]
  /** Yalnızca `today` gününe ait (silinmemiş) rutin tamamlamaları. */
  completions: TaskCompletion[]
}

/** Görevler kartı verisi. */
export function useTodayTasksData(today: ISODate): TodayTasksData | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    const [tasks, completions] = await Promise.all([
      repositories.tasks.findAll(),
      repositories.taskCompletions.findByDate(today),
    ])
    return { tasks, completions }
  }, [repositories, today])
}

export interface TodayTestsData {
  results: TestResult[]
  /** Konu id → ad (zayıf konu listesi için). */
  topicNames: ReadonlyMap<UUID, string>
  /** Ders id → ad. */
  subjectNames: ReadonlyMap<UUID, string>
  /** Konu id → ders id (zayıf konu satırında ders adını göstermek için). */
  topicSubjects: ReadonlyMap<UUID, UUID>
}

/** Son testler kartı verisi. */
export function useTodayTestsData(): TodayTestsData | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    const [results, topics, subjects] = await Promise.all([
      repositories.testResults.findAll(),
      repositories.topics.findAll(),
      repositories.subjects.findAll(),
    ])
    return {
      results,
      topicNames: new Map(topics.map((t) => [t.id, t.name])),
      subjectNames: new Map(subjects.map((s) => [s.id, s.name])),
      topicSubjects: new Map(topics.map((t) => [t.id, t.subjectId])),
    }
  }, [repositories])
}

export interface TodayBooksData {
  books: Book[]
  progress: BookProgress[]
}

/** Kitaplar kartı verisi. */
export function useTodayBooksData(): TodayBooksData | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    const [books, progress] = await Promise.all([
      repositories.books.findAll(),
      repositories.bookProgress.findAll(),
    ])
    return { books, progress }
  }, [repositories])
}
