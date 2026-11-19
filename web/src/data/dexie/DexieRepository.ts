/**
 * `Repository<T>` sözleşmesinin genel Dexie implementasyonu (kurallar: ../repository.ts).
 * Varlığa özel repository'ler bu sınıfı genişletir ve korumalı yardımcıları kullanır.
 */
import type { IndexableType, Table } from 'dexie'
import {
  newId,
  toISODateTime,
  type BaseEntity,
  type EntityName,
  type EntityPatch,
  type NewEntity,
  type UUID,
} from '@/domain'
import {
  EntityNotFoundError,
  type CreateOptions,
  type FindOptions,
  type Repository,
} from '../repository'
import type { LocalChange } from '../sync/SyncService'

export type Clock = () => Date
export type ChangeListener = (change: LocalChange) => void

export interface RepositoryContext {
  /** Zaman kaynağı; testlerde sabitlenebilir. */
  now: Clock
  /** Her başarılı yazmadan sonra çağrılır (sync.recordLocalChange'e bağlanır). */
  onChange: ChangeListener
}

/** Hata mesajlarında kullanılan Türkçe varlık adları. */
const ENTITY_LABELS: Readonly<Record<EntityName, string>> = {
  profiles: 'Profil',
  subjects: 'Ders',
  topics: 'Konu',
  books: 'Kitap',
  bookProgress: 'Kitap ilerlemesi',
  testResults: 'Test sonucu',
  focusSessions: 'Odak oturumu',
  focusSegments: 'Odak aralığı',
  tasks: 'Görev',
  taskCompletions: 'Görev tamamlama',
  friends: 'Arkadaş',
  rooms: 'Oda',
}

export const isActive = (entity: BaseEntity): boolean => entity.deletedAt === null

/** Verilen anahtara göre artan sıralanmış YENİ bir dizi döner (girdi değişmez). */
export function sortBy<T>(items: readonly T[], key: (item: T) => string | number): T[] {
  return [...items].sort((a, b) => {
    const ka = key(a)
    const kb = key(b)
    return ka < kb ? -1 : ka > kb ? 1 : 0
  })
}

export class DexieRepository<T extends BaseEntity> implements Repository<T> {
  protected readonly table: Table<T, UUID>
  protected readonly entity: EntityName
  protected readonly context: RepositoryContext

  constructor(table: Table<T, UUID>, entity: EntityName, context: RepositoryContext) {
    this.table = table
    this.entity = entity
    this.context = context
  }

  async findAll(options?: FindOptions): Promise<T[]> {
    const rows = await this.table.toArray()
    return options?.includeDeleted ? rows : rows.filter(isActive)
  }

  async findById(id: UUID, options?: FindOptions): Promise<T | undefined> {
    const row = await this.table.get(id)
    if (!row) return undefined
    return options?.includeDeleted || isActive(row) ? row : undefined
  }

  async create(input: NewEntity<T>, options?: CreateOptions): Promise<T> {
    const timestamp = this.timestamp()
    // Ortak alanlar en sonda: girdide (çalışma zamanında) olsalar bile ezilirler.
    const entity = {
      ...input,
      id: options?.id ?? newId(),
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: null,
    } as T
    await this.table.add(entity)
    this.emit(entity.id, 'upsert', timestamp)
    return entity
  }

  async update(id: UUID, patch: EntityPatch<T>): Promise<T> {
    const timestamp = this.timestamp()
    const updated = await this.table.db.transaction('rw', this.table, async () => {
      const existing = await this.requireActive(id)
      const next: T = {
        ...existing,
        ...patch,
        id: existing.id,
        createdAt: existing.createdAt,
        deletedAt: existing.deletedAt,
        updatedAt: timestamp,
      }
      await this.table.put(next)
      return next
    })
    this.emit(id, 'upsert', timestamp)
    return updated
  }

  /** Soft delete. Olmayan veya zaten silinmiş kayıtta EntityNotFoundError fırlatır. */
  async delete(id: UUID): Promise<void> {
    const timestamp = this.timestamp()
    await this.table.db.transaction('rw', this.table, async () => {
      const existing = await this.requireActive(id)
      await this.table.put({ ...existing, deletedAt: timestamp, updatedAt: timestamp })
    })
    this.emit(id, 'delete', timestamp)
  }

  /** İndekslenmiş bir alana eşit olan, silinmemiş kayıtlar. */
  protected async findActiveWhere(index: string, value: IndexableType): Promise<T[]> {
    const rows = await this.table.where(index).equals(value).toArray()
    return rows.filter(isActive)
  }

  private async requireActive(id: UUID): Promise<T> {
    const existing = await this.table.get(id)
    if (!existing || !isActive(existing)) {
      throw new EntityNotFoundError(ENTITY_LABELS[this.entity], id)
    }
    return existing
  }

  private timestamp(): string {
    return toISODateTime(this.context.now())
  }

  private emit(id: UUID, op: LocalChange['op'], at: string): void {
    this.context.onChange({ entity: this.entity, id, op, at })
  }
}
