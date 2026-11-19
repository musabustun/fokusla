/**
 * Varlığa özel Dexie repository'leri ve `Repositories` fabrikası.
 * Tüm bulucular soft-delete edilmiş kayıtları HARİÇ tutar.
 */
import {
  toISODateTime,
  type BookProgress,
  type FocusSegment,
  type FocusSession,
  type ISODate,
  type Subject,
  type TaskCompletion,
  type TestResult,
  type Topic,
  type UserProfile,
  type UUID,
} from '@/domain'
import type {
  BookProgressRepository,
  FocusSegmentRepository,
  FocusSessionRepository,
  ProfileRepository,
  Repositories,
  SubjectRepository,
  TaskCompletionRepository,
  TestResultRepository,
  TopicRepository,
} from '../repository'
import type { FokusDatabase } from './db'
import { DexieRepository, isActive, sortBy, type RepositoryContext } from './DexieRepository'

export class DexieProfileRepository
  extends DexieRepository<UserProfile>
  implements ProfileRepository
{
  /** Cihazdaki tek profil; birden fazlaysa en eski oluşturulan. */
  async getCurrent(): Promise<UserProfile | undefined> {
    const profiles = await this.findAll()
    return sortBy(profiles, (p) => p.createdAt)[0]
  }
}

export class DexieSubjectRepository extends DexieRepository<Subject> implements SubjectRepository {
  async findByCatalogKey(catalogKey: string): Promise<Subject | undefined> {
    const matches = await this.findActiveWhere('catalogKey', catalogKey)
    return matches[0]
  }
}

export class DexieTopicRepository extends DexieRepository<Topic> implements TopicRepository {
  /** `order`'a göre artan. */
  async findBySubject(subjectId: UUID): Promise<Topic[]> {
    return sortBy(await this.findActiveWhere('subjectId', subjectId), (t) => t.order)
  }
}

export class DexieBookProgressRepository
  extends DexieRepository<BookProgress>
  implements BookProgressRepository
{
  /** `recordedAt`'e göre artan (güncel konum = son eleman). */
  async findByBook(bookId: UUID): Promise<BookProgress[]> {
    return sortBy(await this.findActiveWhere('bookId', bookId), (p) => p.recordedAt)
  }
}

export class DexieTestResultRepository
  extends DexieRepository<TestResult>
  implements TestResultRepository
{
  /** `takenAt`'e göre artan. */
  async findBySubject(subjectId: UUID): Promise<TestResult[]> {
    return sortBy(await this.findActiveWhere('subjectId', subjectId), (r) => r.takenAt)
  }

  /** `takenAt`'e göre artan. */
  async findByTopic(topicId: UUID): Promise<TestResult[]> {
    return sortBy(await this.findActiveWhere('topicId', topicId), (r) => r.takenAt)
  }
}

export class DexieFocusSessionRepository
  extends DexieRepository<FocusSession>
  implements FocusSessionRepository
{
  /** endedAt === null olan oturum; tutarsızlık halinde en son başlayan. */
  async findActive(): Promise<FocusSession | undefined> {
    const open = await this.table.filter((s) => isActive(s) && s.endedAt === null).toArray()
    return sortBy(open, (s) => s.startedAt).at(-1)
  }

  /** startedAt ∈ [from, to), `startedAt`'e göre artan. */
  async findStartedBetween(from: Date, to: Date): Promise<FocusSession[]> {
    const rows = await this.table
      .where('startedAt')
      .between(toISODateTime(from), toISODateTime(to), true, false)
      .toArray()
    return sortBy(rows.filter(isActive), (s) => s.startedAt)
  }
}

export class DexieFocusSegmentRepository
  extends DexieRepository<FocusSegment>
  implements FocusSegmentRepository
{
  /** `startedAt`'e göre artan. */
  async findBySession(sessionId: UUID): Promise<FocusSegment[]> {
    return sortBy(await this.findActiveWhere('sessionId', sessionId), (s) => s.startedAt)
  }
}

export class DexieTaskCompletionRepository
  extends DexieRepository<TaskCompletion>
  implements TaskCompletionRepository
{
  /** `completedAt`'e göre artan. */
  async findByDate(date: ISODate): Promise<TaskCompletion[]> {
    return sortBy(await this.findActiveWhere('date', date), (c) => c.completedAt)
  }

  /** `date`'e göre artan. */
  async findByTask(taskId: UUID): Promise<TaskCompletion[]> {
    return sortBy(await this.findActiveWhere('taskId', taskId), (c) => c.date)
  }
}

export function createRepositories(db: FokusDatabase, context: RepositoryContext): Repositories {
  return {
    profiles: new DexieProfileRepository(db.profiles, 'profiles', context),
    subjects: new DexieSubjectRepository(db.subjects, 'subjects', context),
    topics: new DexieTopicRepository(db.topics, 'topics', context),
    books: new DexieRepository(db.books, 'books', context),
    bookProgress: new DexieBookProgressRepository(db.bookProgress, 'bookProgress', context),
    testResults: new DexieTestResultRepository(db.testResults, 'testResults', context),
    focusSessions: new DexieFocusSessionRepository(db.focusSessions, 'focusSessions', context),
    focusSegments: new DexieFocusSegmentRepository(db.focusSegments, 'focusSegments', context),
    tasks: new DexieRepository(db.tasks, 'tasks', context),
    taskCompletions: new DexieTaskCompletionRepository(
      db.taskCompletions,
      'taskCompletions',
      context,
    ),
    friends: new DexieRepository(db.friends, 'friends', context),
    rooms: new DexieRepository(db.rooms, 'rooms', context),
  }
}
