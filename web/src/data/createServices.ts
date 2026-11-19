import { MockAuthService } from './auth/MockAuthService'
import { createDatabase, DEFAULT_DB_NAME } from './dexie/db'
import { DexieLocalDataService } from './dexie/DexieLocalDataService'
import { createRepositories } from './dexie/repositories'
import type { AppServices } from './services'
import { MockSocialService, type MockSocialServiceOptions } from './social/MockSocialService'
import { MockSyncService } from './sync/MockSyncService'

export interface CreateServicesOptions {
  /** IndexedDB adı. Testlerde benzersiz bir ad ver (ör. `crypto.randomUUID()`). */
  dbName?: string
  /** Mock "Apple ile Giriş" gecikmesi (ms). Testlerde 0. */
  authDelayMs?: number
  /** Mock senkron gecikmesi (ms). Testlerde 0. */
  syncDelayMs?: number
  /** Zaman kaynağı; testlerde sabitlenebilir. */
  now?: () => Date
  /** Mock sosyal servisin gecikme/simülasyon ayarları. Testlerde gecikmeler 0. */
  social?: Pick<MockSocialServiceOptions, 'delayMs' | 'tickMs' | 'responseDelayMs' | 'random'>
}

/** Uygulama servislerini kurar: Dexie repository'leri + mock auth + mock sync + mock sosyal. */
export function createServices(options: CreateServicesOptions = {}): AppServices {
  const now = options.now ?? (() => new Date())
  const db = createDatabase(options.dbName ?? DEFAULT_DB_NAME)
  const sync = new MockSyncService({ delayMs: options.syncDelayMs, now })
  const auth = new MockAuthService({ delayMs: options.authDelayMs })
  const repositories = createRepositories(db, {
    now,
    onChange: (change) => sync.recordLocalChange(change),
  })
  const localData = new DexieLocalDataService(db, now)
  const social = new MockSocialService({ auth, now, ...options.social })
  return { repositories, auth, sync, localData, social }
}
