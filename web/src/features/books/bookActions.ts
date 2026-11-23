/**
 * Kitap modülünün yazma işlemleri. Ekranlar repository'yi doğrudan değil bunları çağırır;
 * böylece doğrulama ve "kitap silinince kayıtları da sil" gibi kurallar tek yerde kalır.
 */
import type { Repositories } from '@/data'
import {
  normalizeBarcode,
  toISODateTime,
  type Book,
  type BookKind,
  type BookUnit,
  type UUID,
} from '@/domain'

/** Kitap formunun değerleri (ad dışındaki metin alanları boşsa null'a çevrilir). */
export interface BookInput {
  title: string
  publisher: string | null
  kind: BookKind
  subjectId: UUID | null
  unit: BookUnit
  /** Toplam birim; bilinmiyorsa null. Pozitif tam sayı olmalı. */
  totalUnits: number | null
  /**
   * Barkod (ham metin olabilir; kayıtta EAN-13'e normalize edilir, boş → null, geçersiz → hata).
   * Verilmezse (undefined) güncellemede mevcut barkod korunur.
   */
  barcode?: string | null
  /** Kütüphane kaydının anahtarı. Verilmezse güncellemede korunur, oluşturmada null. */
  libraryKey?: string | null
  /** Yeni kitapla birlikte oluşturulacak bölümler (yalnızca `createBook`). */
  sections?: readonly SectionInput[]
}

/** Kitabın bir bölümü (`bookId` kayıtta eklenir). */
export interface SectionInput {
  title: string
  order: number
  startUnit: number | null
  endUnit: number | null
  topicId: UUID | null
}

export const INVALID_BARCODE_MESSAGE = 'Geçerli bir barkod değil. 13 haneli numarayı kontrol et.'

export class BookValidationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'BookValidationError'
  }
}

export type BookRepos = Pick<Repositories, 'books' | 'bookProgress' | 'bookSections' | 'subjects'>

/** undefined → undefined (dokunma); boş → null; geçerli → EAN-13; aksi hâlde hata. */
function normalizeBarcodeInput(raw: string | null | undefined): string | null | undefined {
  if (raw === undefined) return undefined
  if (raw === null || raw.trim() === '') return null
  const barcode = normalizeBarcode(raw)
  if (barcode === null) throw new BookValidationError(INVALID_BARCODE_MESSAGE)
  return barcode
}

function normalize(input: BookInput): BookInput {
  const title = input.title.trim()
  if (title === '') throw new BookValidationError('Kitap adı boş olamaz.')
  const total = input.totalUnits
  if (total !== null && (!Number.isInteger(total) || total <= 0)) {
    throw new BookValidationError('Toplam pozitif bir tam sayı olmalı.')
  }
  const publisher = input.publisher?.trim() ?? ''
  const barcode = normalizeBarcodeInput(input.barcode)
  return {
    ...input,
    title,
    publisher: publisher === '' ? null : publisher,
    ...(barcode === undefined ? {} : { barcode }),
  }
}

async function examOf(repos: BookRepos, subjectId: UUID | null) {
  if (subjectId === null) return null
  return (await repos.subjects.findById(subjectId))?.exam ?? null
}

export async function createBook(repos: BookRepos, input: BookInput): Promise<Book> {
  const { sections = [], ...clean } = normalize(input)
  const book = await repos.books.create({
    title: clean.title,
    publisher: clean.publisher,
    kind: clean.kind,
    subjectId: clean.subjectId,
    unit: clean.unit,
    totalUnits: clean.totalUnits,
    exam: await examOf(repos, clean.subjectId),
    barcode: clean.barcode ?? null,
    libraryKey: clean.libraryKey ?? null,
    archivedAt: null,
  })
  for (const section of sections) {
    await repos.bookSections.create({ ...section, bookId: book.id })
  }
  return book
}

export async function updateBook(repos: BookRepos, id: UUID, input: BookInput): Promise<Book> {
  // Bölümler yalnızca oluşturmada yazılır; güncelleme mevcut bölümlere dokunmaz.
  const { sections: _sections, ...clean } = normalize(input)
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
  const [entries, sections] = await Promise.all([
    repos.bookProgress.findByBook(id),
    repos.bookSections.findByBook(id),
  ])
  await Promise.all(entries.map((entry) => repos.bookProgress.delete(entry.id)))
  await Promise.all(sections.map((section) => repos.bookSections.delete(section.id)))
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
