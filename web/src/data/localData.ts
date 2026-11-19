/**
 * Cihazdaki verinin bütününe dair işlemler: dışa aktarma ve tümünü silme (Ayarlar > Veri).
 * Web'de Dexie ile gerçeklenir (`dexie/DexieLocalDataService.ts`); Swift'te SwiftData
 * `ModelContext` üzerinden (JSON dışa aktarma `Codable` ile, silme `delete(model:)` ile).
 */
import type { EntityMap, EntityName, ISODateTime } from '@/domain'

/** Dışa aktarma dosyasının biçim sürümü. Biçim değişirse artırılır. */
export const DATA_EXPORT_FORMAT_VERSION = 1

/** `JSON.stringify` ile dosyaya yazılan tam yedek. Yalnızca silinmemiş kayıtlar içerir. */
export interface DataExport {
  app: 'fokus'
  formatVersion: typeof DATA_EXPORT_FORMAT_VERSION
  exportedAt: ISODateTime
  entities: { [K in EntityName]: EntityMap[K][] }
}

export interface LocalDataService {
  /** Tüm tabloları okur; soft-delete edilmiş kayıtlar dahil EDİLMEZ. Kimlik bilgisi içermez. */
  exportAll(): Promise<DataExport>
  /**
   * Tüm tabloları KALICI olarak boşaltır (tombstone'lar dahil). Müfredat kataloğunu yeniden
   * tohumlamak, oturumu kapatmak ve yönlendirmek çağıranın işidir. Geri alınamaz.
   * Senkron kuyruğuna yazmaz: native'de silme iCloud'a da yansıyabilir (arayüz bunu belirtmeli).
   */
  deleteAll(): Promise<void>
}
