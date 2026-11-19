import type { ISODate, ISODateTime, UUID } from './types'

/** Yeni bir v4 UUID üretir. */
export function newId(): UUID {
  return crypto.randomUUID()
}

/** Şu anın ISO 8601 UTC zaman damgası. Testlerde `now` parametresiyle sabitlenebilir. */
export function toISODateTime(date: Date = new Date()): ISODateTime {
  return date.toISOString()
}

/** Verilen anın YEREL takvim günü (YYYY-MM-DD). */
export function toISODate(date: Date = new Date()): ISODate {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}
