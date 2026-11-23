import type { BookKind, BookUnit, ExamType, UUID } from '@/domain'
import { catalogEntityId, normalizeBarcode } from '@/domain'
import type { BookLibrary, LibraryBook } from './types'

/** Kitap formunu dolduracak düz nesne (id'ler `catalogEntityId` ile UUID'ye çevrilmiş). */
export interface ResolvedLibraryBook {
  libraryKey: string
  /** Aranan (normalleştirilmiş) barkod; verilmediyse yok. */
  barcode?: string
  title: string
  publisher: string | null
  kind: BookKind
  exam: ExamType | null
  subjectId: UUID | null
  unit: BookUnit
  totalUnits: number | null
  sections: {
    title: string
    order: number
    startUnit: number | null
    endUnit: number | null
    topicId: UUID | null
  }[]
}

/** Ham barkodu normalleştirip eşleşen kaydı döndürür; geçersiz barkod veya eşleşme yoksa null. */
export function findLibraryBook(library: BookLibrary, rawBarcode: string): LibraryBook | null {
  const barcode = normalizeBarcode(rawBarcode)
  if (barcode === null) return null
  return library.books.find((book) => book.barcodes.includes(barcode)) ?? null
}

async function idOrNull(catalogKey: string | null): Promise<UUID | null> {
  return catalogKey === null ? null : catalogEntityId(catalogKey)
}

/** Katalog kaydını kitap formuna çevirir; ders/konu anahtarları deterministik UUID olur. */
export async function resolveLibraryBook(
  book: LibraryBook,
  barcode?: string,
): Promise<ResolvedLibraryBook> {
  const sections = await Promise.all(
    book.sections.map(async (section) => ({
      title: section.title,
      order: section.order,
      startUnit: section.startUnit,
      endUnit: section.endUnit,
      topicId: await idOrNull(section.topicCatalogKey),
    })),
  )
  const normalized = barcode === undefined ? null : normalizeBarcode(barcode)
  return {
    libraryKey: book.key,
    ...(normalized === null ? {} : { barcode: normalized }),
    title: book.title,
    publisher: book.publisher,
    kind: book.kind,
    exam: book.exam,
    subjectId: await idOrNull(book.subjectCatalogKey),
    unit: book.unit,
    totalUnits: book.totalUnits,
    sections,
  }
}
