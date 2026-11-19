/**
 * Veri katmanı React hook'ları. Feature'lar Dexie'yi ASLA doğrudan import etmez;
 * canlı (reaktif) okumalar için bu hook'ları kullanır.
 */
import { useLiveQuery } from 'dexie-react-hooks'
import { useCallback, useSyncExternalStore } from 'react'
import type { UserProfile } from '@/domain'
import { useServices } from './ServicesContext'
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
