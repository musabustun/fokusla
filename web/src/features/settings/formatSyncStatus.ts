import type { SyncState } from '@/data'

const dateTimeFormat = new Intl.DateTimeFormat('tr-TR', { dateStyle: 'long', timeStyle: 'short' })

/** Senkron durumunun kısa Türkçe özeti (satır alt başlığı için). */
export function formatSyncStatus(state: SyncState): string {
  switch (state.kind) {
    case 'disabled':
      return 'Kapalı'
    case 'syncing':
      return 'Senkronize ediliyor…'
    case 'error':
      return `Hata: ${state.message}`
    case 'idle':
      return state.lastSyncedAt
        ? `Son senkron: ${dateTimeFormat.format(new Date(state.lastSyncedAt))}`
        : 'Açık · henüz senkronize edilmedi'
  }
}
