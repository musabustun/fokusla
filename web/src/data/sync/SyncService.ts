/**
 * Senkron sözleşmesi. Gerçek senkron YALNIZCA native uygulamada Apple CloudKit
 * (private database) ile yapılacak. Web prototipinde MockSyncService hiçbir yere veri
 * göndermez; yalnızca durum makinesini ve UI akışını taklit eder.
 */
import type { EntityName, ISODateTime, UUID } from '@/domain'

export type SyncState =
  | { kind: 'disabled' }
  | { kind: 'idle'; lastSyncedAt: ISODateTime | null }
  | { kind: 'syncing' }
  | { kind: 'error'; message: string }

export interface LocalChange {
  entity: EntityName
  id: UUID
  op: 'upsert' | 'delete'
  at: ISODateTime
}

export interface SyncService {
  getState(): SyncState
  /** Durum değişikliklerini dinler; aboneliği kaldıran fonksiyon döner. */
  subscribe(listener: (state: SyncState) => void): () => void
  /** Senkronu açar (Apple ile giriş gerektirir — native'de iCloud hesabı). */
  enable(): Promise<void>
  disable(): Promise<void>
  /** Bekleyen değişiklikleri gönderir/çeker. */
  syncNow(): Promise<void>
  /** Repository'ler her yazmadan sonra çağırır; bekleyen değişiklik kuyruğuna eklenir. */
  recordLocalChange(change: LocalChange): void
  /** Henüz gönderilmemiş değişiklik sayısı. */
  pendingChangeCount(): number
}
