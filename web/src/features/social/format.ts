/**
 * Sosyal ekranının Türkçe süre/durum biçimleri. Süreler domain/calc/social.ts'ten (ms) gelir.
 */
import type { PresenceState } from '@/domain'

const MINUTE_MS = 60_000

const safeMs = (ms: number): number => (Number.isFinite(ms) && ms > 0 ? ms : 0)

/** Kısa süre: "2 sa 05 dk", "25 dk", "1 dk'dan az", hiç yoksa "0 dk". */
export function formatDurationShort(ms: number): string {
  const safe = safeMs(ms)
  if (safe === 0) return '0 dk'
  const totalMinutes = Math.floor(safe / MINUTE_MS)
  if (totalMinutes < 1) return "1 dk'dan az"
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours === 0) return `${minutes} dk`
  return `${hours} sa ${String(minutes).padStart(2, '0')} dk`
}

/** Kronometre: "04:09", "1:05:09". */
export function formatClock(ms: number): string {
  const totalSeconds = Math.floor(safeMs(ms) / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  const mm = String(minutes).padStart(2, '0')
  const ss = String(seconds).padStart(2, '0')
  return hours > 0 ? `${hours}:${mm}:${ss}` : `${mm}:${ss}`
}

/** Ekran okuyucu için kronometre: "1 saat 5 dakika 9 saniye". */
export function formatClockLabel(ms: number): string {
  const totalSeconds = Math.floor(safeMs(ms) / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  const parts = [
    hours > 0 ? `${hours} saat` : null,
    minutes > 0 ? `${minutes} dakika` : null,
    `${seconds} saniye`,
  ]
  return parts.filter((part): part is string => part !== null).join(' ')
}

export const PRESENCE_LABEL: Record<PresenceState, string> = {
  focusing: 'Odakta',
  onBreak: 'Molada',
  offline: 'Çevrimdışı',
}

/** Durum + süre: "Odakta · 25 dk", "Çevrimdışı". */
export function formatPresenceLine(state: PresenceState, stateMs: number): string {
  if (state === 'offline') return PRESENCE_LABEL.offline
  return `${PRESENCE_LABEL[state]} · ${formatDurationShort(stateMs)}`
}

/** Paylaşılabilir davet bağlantısı (web prototipi: aynı köken; native: evrensel bağlantı). */
export function inviteLink(origin: string, socialPath: string, inviteCode: string): string {
  return `${origin}${socialPath}?davet=${encodeURIComponent(inviteCode)}`
}
