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

/**
 * Müfredat kataloğu kayıtlarının (Subject/Topic) kimlik ad alanı. ASLA DEĞİŞTİRME:
 * her cihaz aynı catalogKey için aynı id'yi üretir, böylece CloudKit'te kopya oluşmaz.
 * Swift: aynı UUID v5 algoritması (CryptoKit Insecure.SHA1) ve aynı ad alanı.
 */
export const CATALOG_NAMESPACE: UUID = '2af57060-c631-4c67-8d55-0db8f6b7c869'

function uuidToBytes(uuid: UUID): Uint8Array {
  const hex = uuid.replace(/-/g, '')
  return Uint8Array.from({ length: 16 }, (_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16))
}

function bytesToUuid(bytes: Uint8Array): UUID {
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`
}

/** RFC 4122 UUID v5 (SHA-1, isim tabanlı, deterministik). Küçük harf döner. */
export async function uuidV5(name: string, namespace: UUID): Promise<UUID> {
  const nameBytes = new TextEncoder().encode(name)
  const input = new Uint8Array(16 + nameBytes.length)
  input.set(uuidToBytes(namespace), 0)
  input.set(nameBytes, 16)
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-1', input)).slice(0, 16)
  hash[6] = ((hash[6] ?? 0) & 0x0f) | 0x50
  hash[8] = ((hash[8] ?? 0) & 0x3f) | 0x80
  return bytesToUuid(hash)
}

/** Katalog kaydının (catalogKey) tüm cihazlarda aynı olan id'si. */
export function catalogEntityId(catalogKey: string): Promise<UUID> {
  return uuidV5(catalogKey, CATALOG_NAMESPACE)
}
