/**
 * Veri katmanı React hook'ları. Feature'lar Dexie'yi ASLA doğrudan import etmez;
 * canlı (reaktif) okumalar için bu hook'ları kullanır.
 */
import { useLiveQuery } from 'dexie-react-hooks'
import { useCallback, useEffect, useState, useSyncExternalStore } from 'react'
import { toISODate, type ISODate, type UserProfile } from '@/domain'
import { useServices } from './ServicesContext'
import type { SocialSnapshot } from './social/SocialService'
import type { SyncState } from './sync/SyncService'

/**
 * Repository okumasını canlı izler; ilgili tablolar değişince yeniden çalışır.
 * Yükleme sırasında `undefined` döner. `query` yalnızca repository metotlarını (Dexie)
 * çağırmalıdır; fetch gibi başka async API'ler canlı izlemeyi bozar.
 *
 * @example const topics = useLiveData(() => repositories.topics.findBySubject(id), [id])
 */
export function useLiveData<T>(query: () => Promise<T>, deps: readonly unknown[]): T | undefined {
  return useLiveQuery(query, [...deps])
}

/**
 * Mevcut profil durumu. Yükleniyor ile "profil yok" ayrımı onboarding kapısı için önemlidir:
 *  - `{ status: 'loading' }`: henüz okunmadı, hiçbir yönlendirme yapma.
 *  - `{ status: 'ready', profile: undefined }`: cihazda profil yok → onboarding.
 *  - `{ status: 'ready', profile }`: profil var.
 */
export type CurrentProfileState =
  { status: 'loading' } | { status: 'ready'; profile: UserProfile | undefined }

const LOADING: CurrentProfileState = { status: 'loading' }

export function useCurrentProfile(): CurrentProfileState {
  const { repositories } = useServices()
  const state = useLiveQuery(
    async (): Promise<CurrentProfileState> => ({
      status: 'ready',
      profile: await repositories.profiles.getCurrent(),
    }),
    [repositories],
  )
  return state ?? LOADING
}

/** Senkron durumunu izler (MockSyncService / ileride CloudKit). */
export function useSyncState(): SyncState {
  const { sync } = useServices()
  const subscribe = useCallback((onChange: () => void) => sync.subscribe(onChange), [sync])
  const getSnapshot = useCallback(() => sync.getState(), [sync])
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

const DEFAULT_NOW_INTERVAL_MS = 1000

/**
 * `intervalMs` aralıklarla yeniden render tetikleyen güncel zaman (canlı süreler için).
 * Yalnızca "şimdi"yi verir; süreler her zaman zaman damgalarından hesaplanır, burada birikmez.
 */
export function useNow(intervalMs: number = DEFAULT_NOW_INTERVAL_MS): Date {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs)
    return () => clearInterval(id)
  }, [intervalMs])
  return now
}

/** Bir sonraki yerel gece yarısına (+1 sn pay) kalan milisaniye. */
export function msUntilNextLocalMidnight(now: Date): number {
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 1)
  return Math.max(0, next.getTime() - now.getTime())
}

/**
 * Bugünün YEREL günü (`YYYY-MM-DD`). Gece yarısında ve sekme yeniden görünür olduğunda
 * (uyku/arka plan sonrası) güncellenir.
 */
export function useLocalToday(): ISODate {
  const [today, setToday] = useState(() => toISODate(new Date()))

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined
    const refresh = () => {
      setToday(toISODate(new Date()))
      schedule()
    }
    function schedule() {
      clearTimeout(timer)
      timer = setTimeout(refresh, msUntilNextLocalMidnight(new Date()))
    }
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') refresh()
    }
    schedule()
    document.addEventListener('visibilitychange', handleVisibility)
    return () => {
      clearTimeout(timer)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [])

  return today
}

/** Sosyal servis durumunu izler; ilk açılışta oturumu/profili okur (hata konsola yazılır). */
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
