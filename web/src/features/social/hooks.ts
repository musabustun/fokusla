/**
 * Sosyal ekranının hook'ları. Veri yalnızca @/data üzerinden okunur; focus kayıtlarına YAZILMAZ.
 */
import { useCallback, useEffect, useState, useSyncExternalStore } from 'react'
import { useLiveData, useServices, type SocialSnapshot } from '@/data'
import { ownPresenceFromFocus, type OwnFocusSnapshot } from '@/domain/calc/social'

/** Sosyal servis durumunu izler; ilk açılışta oturumu/profili okur. */
export function useSocialSnapshot(): SocialSnapshot {
  const { social } = useServices()
  const subscribe = useCallback((onChange: () => void) => social.subscribe(onChange), [social])
  const getSnapshot = useCallback(() => social.getSnapshot(), [social])
  const snapshot = useSyncExternalStore(subscribe, getSnapshot, getSnapshot)

  useEffect(() => {
    social.refresh().catch((error: unknown) => {
      console.error('Sosyal durum okunamadı', error)
    })
  }, [social])

  return snapshot
}

/** Her `intervalMs`'de bir güncellenen şimdiki zaman (canlı süreler için). */
export function useNow(intervalMs = 1000): Date {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs)
    return () => clearInterval(id)
  }, [intervalMs])
  return now
}

const DAY_MS = 24 * 60 * 60 * 1000

function startOfLocalDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

/**
 * Kendi odak durumumun ham verisi: aktif oturum + bugünkü segmentler. Focus modülünün
 * repository'lerinden YALNIZCA OKUR. Yüklenirken undefined.
 */
export function useOwnFocusSnapshot(): OwnFocusSnapshot | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    const dayStart = startOfLocalDay(new Date())
    const dayEnd = new Date(dayStart.getTime() + DAY_MS)
    const [activeSession, todaySessions] = await Promise.all([
      repositories.focusSessions.findActive(),
      repositories.focusSessions.findStartedBetween(dayStart, dayEnd),
    ])
    const sessionIds = new Set(todaySessions.map((session) => session.id))
    if (activeSession) sessionIds.add(activeSession.id)
    const segmentLists = await Promise.all(
      [...sessionIds].map((id) => repositories.focusSegments.findBySession(id)),
    )
    return { activeSession, segments: segmentLists.flat() }
  }, [repositories])
}

/** Native'deki kalp atışı gibi: durum değişince ve bu aralıkla yeniden yayınla. */
export const PRESENCE_HEARTBEAT_MS = 60_000

/**
 * Kendi durumumu (focus verisinden türetilmiş) sosyal servise yayınlar. Yalnızca Sosyal
 * açıkken çalışır (web prototipi kısıtı; native'de arka planda yayınlanacak).
 */
export function usePublishOwnPresence(focus: OwnFocusSnapshot | undefined, enabled: boolean) {
  const { social } = useServices()
  useEffect(() => {
    if (!enabled || !focus) return
    const publish = () => {
      social.publishPresence(ownPresenceFromFocus(focus, new Date())).catch((error: unknown) => {
        console.error('Durum yayınlanamadı', error)
      })
    }
    publish()
    const id = setInterval(publish, PRESENCE_HEARTBEAT_MS)
    return () => clearInterval(id)
  }, [social, focus, enabled])
}
