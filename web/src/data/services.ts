import type { AuthService } from './auth/AuthService'
import type { LocalDataService } from './localData'
import type { Repositories } from './repository'
import type { SyncService } from './sync/SyncService'

/** Uygulamanın tüm servisleri. Testlerde sahte (fake) bir AppServices verilebilir. */
export interface AppServices {
  repositories: Repositories
  auth: AuthService
  sync: SyncService
  /** Tüm yerel veriyi dışa aktarma / silme (Ayarlar > Veri). */
  localData: LocalDataService
}
