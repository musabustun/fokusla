/**
 * Aktif odak oturumu (Dexie'den canlı okunur) ve eylemleri. Durum yalnızca veritabanında
 * yaşar: sayfa yenilense ya da sekme kapansa da oturum kaldığı yerden devam eder.
 */
import { useCallback, useRef, useState } from 'react'
import { useLiveData, useServices } from '@/data'
import type { FocusSegment, FocusSession, Subject, Topic } from '@/domain'
import { computeSessionStats, type FocusSessionStats } from '@/domain/calc/focus'
import {
  finishFocusSession,
  pauseFocusSession,
  resumeFocusSession,
  startFocusSession,
  type StartFocusInput,
} from './focusActions'

export interface ActiveFocus {
  session: FocusSession
  segments: FocusSegment[]
  subject: Subject | undefined
  topic: Topic | undefined
}

export interface UseFocusSessionResult {
  /** `undefined`: yükleniyor; `null`: açık oturum yok. */
  active: ActiveFocus | null | undefined
  error: string | null
  start: (input: StartFocusInput) => Promise<boolean>
  pause: () => Promise<boolean>
  resume: () => Promise<boolean>
  /** Oturumu bitirir ve özet istatistiklerini döndürür (başarısızsa null). */
  finish: () => Promise<FocusSessionStats | null>
}

const SAVE_ERROR = 'İşlem kaydedilemedi. Lütfen tekrar dene.'

function useActiveFocus(): ActiveFocus | null | undefined {
  const { repositories } = useServices()
  return useLiveData(async (): Promise<ActiveFocus | null> => {
    const session = await repositories.focusSessions.findActive()
    if (!session) return null
    const [segments, subject, topic] = await Promise.all([
      repositories.focusSegments.findBySession(session.id),
      session.subjectId ? repositories.subjects.findById(session.subjectId) : undefined,
      session.topicId ? repositories.topics.findById(session.topicId) : undefined,
    ])
    return { session, segments, subject, topic }
  }, [repositories])
}

export function useFocusSession(): UseFocusSessionResult {
  const { repositories } = useServices()
  const active = useActiveFocus()
  const [error, setError] = useState<string | null>(null)
  // Çift tıklamada iki oturum açılmasını önler (buton devre dışı bırakılmaz, odak kaybolmasın).
  const busyRef = useRef(false)
  const sessionId = active?.session.id

  const run = useCallback(async <T>(action: () => Promise<T>): Promise<T | null> => {
    if (busyRef.current) return null
    busyRef.current = true
    try {
      const result = await action()
      setError(null)
      return result
    } catch {
      setError(SAVE_ERROR)
      return null
    } finally {
      busyRef.current = false
    }
  }, [])

  const start = useCallback(
    async (input: StartFocusInput) =>
      (await run(() => startFocusSession(repositories, input, new Date()))) !== null,
    [repositories, run],
  )

  const pause = useCallback(async () => {
    if (!sessionId) return false
    return (await run(() => pauseFocusSession(repositories, sessionId, new Date()))) !== null
  }, [repositories, run, sessionId])

  const resume = useCallback(async () => {
    if (!sessionId) return false
    return (await run(() => resumeFocusSession(repositories, sessionId, new Date()))) !== null
  }, [repositories, run, sessionId])

  const finish = useCallback(async () => {
    if (!sessionId) return null
    return run(async () => {
      const now = new Date()
      await finishFocusSession(repositories, sessionId, now)
      const segments = await repositories.focusSegments.findBySession(sessionId)
      return computeSessionStats(segments, now)
    })
  }, [repositories, run, sessionId])

  return { active, error, start, pause, resume, finish }
}
