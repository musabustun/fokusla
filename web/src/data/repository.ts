/**
 * Repository sözleşmeleri. Feature'lar veriye YALNIZCA bu arayüzler üzerinden erişir
 * (useServices().repositories). Implementasyon: Dexie (src/data/dexie/*).
 * Swift tarafında aynı arayüzler SwiftData ModelContext üzerine yazılacak.
 *
 * Kurallar:
 *  - Tüm okumalar varsayılan olarak soft-delete edilmiş kayıtları (deletedAt != null) HARİÇ tutar.
 *  - create/update yeni bir nesne döndürür; girdiler mutasyona uğramaz.
 *  - create: id (UUID v4 ya da options.id), createdAt, updatedAt doldurulur; deletedAt = null.
 *  - update: updatedAt yenilenir; olmayan/silinmiş kayıtta EntityNotFoundError fırlatır.
 *  - delete: soft delete (deletedAt + updatedAt set edilir). Kalıcı silme yoktur.
 */
import type {
  BaseEntity,
  Book,
  BookProgress,
  EntityPatch,
  FocusSegment,
  FocusSession,
  Friend,
  ISODate,
  NewEntity,
  Room,
  Subject,
  Task,
  TaskCompletion,
  TestResult,
  Topic,
  UserProfile,
  UUID,
} from '@/domain'

export interface FindOptions {
  /** true ise soft-delete edilmiş kayıtlar da döner (senkron/debug için). */
  includeDeleted?: boolean
}

export interface CreateOptions {
  /**
   * Önceden belirlenmiş id (ör. katalog kayıtları için catalogEntityId). Verilmezse UUID v4 üretilir.
   * Aynı id ile ikinci create hata verir.
   */
  id?: UUID
}

export interface Repository<T extends BaseEntity> {
  findAll(options?: FindOptions): Promise<T[]>
  findById(id: UUID, options?: FindOptions): Promise<T | undefined>
  create(input: NewEntity<T>, options?: CreateOptions): Promise<T>
  update(id: UUID, patch: EntityPatch<T>): Promise<T>
  /** Soft delete. */
  delete(id: UUID): Promise<void>
}

export class EntityNotFoundError extends Error {
  constructor(entity: string, id: UUID) {
    super(`${entity} bulunamadı: ${id}`)
    this.name = 'EntityNotFoundError'
  }
}

// --- Varlığa özel genişletmeler (feature oturumları ihtiyaç oldukça EKLEME yapabilir) ---

export interface ProfileRepository extends Repository<UserProfile> {
  /** Cihazdaki tek profil; onboarding öncesi undefined. */
  getCurrent(): Promise<UserProfile | undefined>
}

export interface SubjectRepository extends Repository<Subject> {
  findByCatalogKey(catalogKey: string): Promise<Subject | undefined>
}

export interface TopicRepository extends Repository<Topic> {
  findBySubject(subjectId: UUID): Promise<Topic[]>
}

export type BookRepository = Repository<Book>

export interface BookProgressRepository extends Repository<BookProgress> {
  findByBook(bookId: UUID): Promise<BookProgress[]>
}

export interface TestResultRepository extends Repository<TestResult> {
  findBySubject(subjectId: UUID): Promise<TestResult[]>
  findByTopic(topicId: UUID): Promise<TestResult[]>
}

export interface FocusSessionRepository extends Repository<FocusSession> {
  /** endedAt === null olan oturum (en fazla bir tane olmalı). */
  findActive(): Promise<FocusSession | undefined>
  /** startedAt ∈ [from, to) aralığındaki oturumlar. */
  findStartedBetween(from: Date, to: Date): Promise<FocusSession[]>
}

export interface FocusSegmentRepository extends Repository<FocusSegment> {
  findBySession(sessionId: UUID): Promise<FocusSegment[]>
}

export type TaskRepository = Repository<Task>

export interface TaskCompletionRepository extends Repository<TaskCompletion> {
  findByDate(date: ISODate): Promise<TaskCompletion[]>
  findByTask(taskId: UUID): Promise<TaskCompletion[]>
}

export type FriendRepository = Repository<Friend>
export type RoomRepository = Repository<Room>

export interface Repositories {
  profiles: ProfileRepository
  subjects: SubjectRepository
  topics: TopicRepository
  books: BookRepository
  bookProgress: BookProgressRepository
  testResults: TestResultRepository
  focusSessions: FocusSessionRepository
  focusSegments: FocusSegmentRepository
  tasks: TaskRepository
  taskCompletions: TaskCompletionRepository
  friends: FriendRepository
  rooms: RoomRepository
}
