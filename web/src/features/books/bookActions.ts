/**
 * Kitap modülünün yazma işlemleri. Ekranlar repository'yi doğrudan değil bunları çağırır;
 * böylece doğrulama ve "kitap silinince kayıtları da sil" gibi kurallar tek yerde kalır.
 */
import type { Repositories } from '@/data'
import { toISODateTime, type Book, type BookKind, type BookUnit, type UUID } from '@/domain'

/** Kitap formunun değerleri (ad dışındaki metin alanları boşsa null'a çevrilir). */
export interface BookInput {
  title: string
  publisher: string | null
  kind: BookKind
  subjectId: UUID | null
  unit: BookUnit
  /** Toplam birim; bilinmiyorsa null. Pozitif tam sayı olmalı. */
  totalUnits: number | null
}

export class BookValidationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'BookValidationError'
  }
}

export type BookRepos = Pick<Repositories, 'books' | 'bookProgress' | 'subjects'>

function normalize(input: BookInput): BookInput {
  const title = input.title.trim()
  if (title === '') throw new BookValidationError('Kitap adı boş olamaz.')
  const total = input.totalUnits
  if (total !== null && (!Number.isInteger(total) || total <= 0)) {
    throw new BookValidationError('Toplam pozitif bir tam sayı olmalı.')
  }
  const publisher = input.publisher?.trim() ?? ''
  return { ...input, title, publisher: publisher === '' ? null : publisher }
}

async function examOf(repos: BookRepos, subjectId: UUID | null) {
  if (subjectId === null) return null
  return (await repos.subjects.findById(subjectId))?.exam ?? null
}

export async function createBook(repos: BookRepos, input: BookInput): Promise<Book> {
  const clean = normalize(input)
  return repos.books.create({
    ...clean,
    exam: await examOf(repos, clean.subjectId),
    archivedAt: null,
  })
}

export async function updateBook(repos: BookRepos, id: UUID, input: BookInput): Promise<Book> {
  const clean = normalize(input)
  return repos.books.update(id, { ...clean, exam: await examOf(repos, clean.subjectId) })
}

/** Rafa kaldır (`archived: true`) ya da rafa geri al. */
export async function setBookArchived(
  repos: BookRepos,
  id: UUID,
  archived: boolean,
  now: Date = new Date(),
): Promise<Book> {
  return repos.books.update(id, { archivedAt: archived ? toISODateTime(now) : null })
}

/** Kitabı ve tüm ilerleme kayıtlarını soft-delete eder. */
export async function deleteBook(repos: BookRepos, id: UUID): Promise<void> {
  const entries = await repos.bookProgress.findByBook(id)
  await Promise.all(entries.map((entry) => repos.bookProgress.delete(entry.id)))
  await repos.books.delete(id)
}

export interface ProgressInput {
  bookId: UUID
  /** "Nereye kadar geldim": 0 veya pozitif tam sayı. Toplamı aşabilir (calc sınırlar). */
  reachedUnit: number
  note: string | null
}

export async function addProgress(
  repos: BookRepos,
  input: ProgressInput,
  now: Date = new Date(),
): Promise<void> {
  if (!Number.isInteger(input.reachedUnit) || input.reachedUnit < 0) {
    throw new BookValidationError('Geçerli bir sayı gir.')
  }
  const note = input.note?.trim() ?? ''
  await repos.bookProgress.create({
    bookId: input.bookId,
    reachedUnit: input.reachedUnit,
    topicId: null,
    recordedAt: toISODateTime(now),
    note: note === '' ? null : note,
  })
}

export async function deleteProgress(repos: BookRepos, progressId: UUID): Promise<void> {
  await repos.bookProgress.delete(progressId)
}
