/**
 * iOS dışa aktarımı: web kitap kataloğunu Swift `BookLibrary` (Decodable) ile birebir uyumlu,
 * kararlı anahtar sıralı düz nesneye çevirir. Saf fonksiyon; dosya yazmaz.
 * Yazıcı: `web/scripts/export-ios-library.ts` (`npm run export:ios-library`).
 */
import type { BookLibrary } from './types'

export function toIosLibraryJson(library: BookLibrary): BookLibrary {
  return {
    version: library.version,
    updatedAt: library.updatedAt,
    books: library.books.map((book) => ({
      key: book.key,
      barcodes: [...book.barcodes],
      title: book.title,
      publisher: book.publisher,
      kind: book.kind,
      exam: book.exam,
      subjectCatalogKey: book.subjectCatalogKey,
      unit: book.unit,
      totalUnits: book.totalUnits,
      editionYear: book.editionYear,
      sections: book.sections.map((section) => ({
        title: section.title,
        order: section.order,
        startUnit: section.startUnit,
        endUnit: section.endUnit,
        topicCatalogKey: section.topicCatalogKey,
      })),
    })),
  }
}
