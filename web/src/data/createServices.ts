import { MockAuthService } from './auth/MockAuthService'
import { createDatabase, DEFAULT_DB_NAME } from './dexie/db'
import { DexieLocalDataService } from './dexie/DexieLocalDataService'
import { createRepositories } from './dexie/repositories'
import type { AppServices } from './services'
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
}

/** Uygulama servislerini kurar: Dexie repository'leri + mock auth + mock sync. */
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
  return { repositories, auth, sync, localData }
}
