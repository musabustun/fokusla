/**
 * Fokus IndexedDB veritabanı (Dexie 4).
 *
 * Her tablo `EntityMap`'teki bir anahtara ve native tarafta bir SwiftData @Model /
 * CloudKit CKRecord tipine karşılık gelir. Birincil anahtar istemcide üretilen string UUID
 * `id`'dir (auto-increment DEĞİL); bu yüzden ekleme tipi de tam varlıktır (`id` zorunlu).
 *
 * ŞEMA SÜRÜMLERİ YALNIZCA EKLEMELİDİR:
 *  - Yayınlanmış bir `db.version(n)` bloğunu ASLA değiştirme veya silme.
 *  - İndeks/tablo değişikliği için yeni bir `db.version(n + 1).stores({...})` ekle; gerekiyorsa
 *    `.upgrade(tx => ...)` ile veri taşı. Dexie yalnızca değişen tabloları belirtmeyi destekler.
 *
 * NOT: IndexedDB `null` değerleri indekslemez. `deletedAt === null` (silinmemiş) ve
 * `endedAt === null` (aktif) filtreleri indeksle değil, JS tarafında yapılır.
 */
import { Dexie, type EntityTable } from 'dexie'
import type { EntityMap, EntityName } from '@/domain'

export const DEFAULT_DB_NAME = 'fokus'

/** Tablo başına bir EntityTable; ekleme tipi tam varlık (id istemcide üretilir). */
export type FokusTables = {
  [K in EntityName]: EntityTable<EntityMap[K], 'id', EntityMap[K]>
}

export type FokusDatabase = Dexie & FokusTables

/** Sürüm 1 şeması. İlk anahtar birincil anahtardır (`id`), kalanlar ikincil indekslerdir. */
const SCHEMA_V1: Readonly<Record<Exclude<EntityName, 'bookSections'>, string>> = {
  profiles: 'id',
  subjects: 'id, catalogKey, exam',
  topics: 'id, subjectId, catalogKey',
  books: 'id, subjectId',
  bookProgress: 'id, bookId',
  testResults: 'id, subjectId, topicId, takenAt',
  focusSessions: 'id, startedAt',
  focusSegments: 'id, sessionId',
  tasks: 'id, kind, dueDate',
  taskCompletions: 'id, taskId, date, [taskId+date]',
  friends: 'id, remoteUserId',
  rooms: 'id, inviteCode',
}

/**
 * Tipli Dexie örneği oluşturur. Testler benzersiz bir ad vermeli (ör. `crypto.randomUUID()`)
 * ve iş bitince `db.delete()` çağırmalıdır.
 */
export function createDatabase(name: string = DEFAULT_DB_NAME): FokusDatabase {
  const db = new Dexie(name) as FokusDatabase
  db.version(1).stores(SCHEMA_V1)
  // Sürüm 2: kitaba barkod indeksi + bölüm tablosu. Eski kitaplarda yeni alanlar yoktu → null.
  db.version(2)
    .stores({ books: 'id, subjectId, barcode', bookSections: 'id, bookId' })
    .upgrade((tx) =>
      tx
        .table('books')
        .toCollection()
        .modify((book: Record<string, unknown>) => {
          book.barcode ??= null
          book.libraryKey ??= null
        }),
    )
  return db
}
