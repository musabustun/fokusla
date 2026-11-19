/**
 * Kitap modülünün canlı veri hook'ları. Türetilmiş değerler `domain/calc/books.ts`'ten gelir;
 * burada yalnızca repository okumaları ve `now` sağlanır.
 */
import { useServices, useLiveData } from '@/data'
import type { BookProgress, Subject, UUID } from '@/domain'
import { sortProgressHistory, summarizeBooks, type BookSummary } from '@/domain/calc/books'

export interface BooksData {
  /** Silinmemiş tüm kitaplar, son etkinlik en üstte. */
  summaries: BookSummary[]
  /** id → ders (form seçicisi ve grup başlıkları için). */
  subjectsById: ReadonlyMap<UUID, Subject>
  /** Tüm dersler, sınav ve sıra (order) ile sıralı. */
  subjects: Subject[]
}

const EXAM_ORDER = { TYT: 0, AYT: 1, YDT: 2 } as const

/** Tüm kitapların canlı özetleri; yüklenirken undefined. */
export function useBooksData(): BooksData | undefined {
  const { repositories } = useServices()
  return useLiveData(async () => {
    const [books, progress, subjects] = await Promise.all([
      repositories.books.findAll(),
      repositories.bookProgress.findAll(),
      repositories.subjects.findAll(),
    ])
    const sortedSubjects = [...subjects].sort(
      (a, b) => EXAM_ORDER[a.exam] - EXAM_ORDER[b.exam] || a.order - b.order,
    )
    return {
      summaries: summarizeBooks(books, progress, new Date()),
      subjectsById: new Map(sortedSubjects.map((s) => [s.id, s])),
      subjects: sortedSubjects,
    }
  }, [repositories])
}

/** Bir kitabın ilerleme geçmişi, en yeni önce; yüklenirken undefined. */
export function useBookHistory(bookId: UUID): BookProgress[] | undefined {
  const { repositories } = useServices()
  return useLiveData(
    async () => sortProgressHistory(await repositories.bookProgress.findByBook(bookId)),
    [repositories, bookId],
  )
}
