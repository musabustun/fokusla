/**
 * Dexie dışında yerel veri tutan servisleri (ör. sosyal mock'un localStorage önbelleği) Ayarlar >
 * Veri işlemlerine dahil eder: dışa aktarma onların verisini `extras` altına ekler, "tüm verileri
 * sil" onları da temizler. Swift'te karşılığı: SwiftData dışındaki yerel önbelleklerin
 * (UserDefaults, dosyalar) aynı silme/dışa aktarma akışına bağlanması.
 */
import type { DataExport, LocalDataService } from './localData'

export interface LocalDataParticipant {
  /** `DataExport.extras` içindeki anahtar. Benzersiz olmalı. */
  readonly key: string
  /** JSON'a yazılabilir veri döndürür. */
  exportData(): Promise<unknown>
  /** Bu katılımcının cihazdaki tüm verisini kalıcı siler. */
  clearData(): Promise<void>
}

export function withLocalDataParticipants(
  base: LocalDataService,
  participants: readonly LocalDataParticipant[],
): LocalDataService {
  return {
    async exportAll(): Promise<DataExport> {
      const backup = await base.exportAll()
      if (participants.length === 0) return backup
      const entries = await Promise.all(
        participants.map(async (participant) => [participant.key, await participant.exportData()]),
      )
      return { ...backup, extras: Object.fromEntries(entries) }
    },

    async deleteAll(): Promise<void> {
      await base.deleteAll()
      // Biri başarısız olsa bile diğerleri temizlensin; ilk hata sonra bildirilsin.
      const results = await participants.reduce<Promise<unknown[]>>(
        async (previous, participant) => {
          const errors = await previous
          try {
            await participant.clearData()
            return errors
          } catch (error: unknown) {
            return [...errors, error]
          }
        },
        Promise.resolve([]),
      )
      if (results.length > 0) throw results[0]
    },
  }
}
