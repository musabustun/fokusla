import { normalizeBarcode } from '@/domain'
import type { Curriculum } from '@/curriculum'
import type { BookLibrary } from './types'

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/

/** Kataloğu doğrular; hata mesajlarının listesini döndürür (boş liste = geçerli). */
export function validateLibrary(library: BookLibrary, curriculum: Curriculum): string[] {
  const errors: string[] = []
  if (!Number.isInteger(library.version) || library.version < 1) {
    errors.push('version pozitif tam sayı olmalı')
  }
  if (!DATE_PATTERN.test(library.updatedAt)) errors.push('updatedAt YYYY-MM-DD olmalı')

  const topicsBySubject = new Map(
    curriculum.subjects.map((s) => [s.key, new Set(s.topics.map((t) => t.key))]),
  )
  const keys = new Set<string>()
  const barcodeOwners = new Map<string, string>()

  for (const book of library.books) {
    const at = `[${book.key}]`
    if (book.key.trim() === '') errors.push('boş key')
    if (keys.has(book.key)) errors.push(`${at} key benzersiz değil`)
    keys.add(book.key)
    if (book.title.trim() === '') errors.push(`${at} başlık boş`)
    if (book.barcodes.length === 0) errors.push(`${at} en az bir barkod gerekli`)

    for (const barcode of book.barcodes) {
      if (normalizeBarcode(barcode) !== barcode) {
        errors.push(`${at} barkod geçersiz veya normalleştirilmemiş: ${barcode}`)
      }
      const owner = barcodeOwners.get(barcode)
      if (owner !== undefined) errors.push(`${at} barkod ${barcode} zaten [${owner}] kitabında`)
      else barcodeOwners.set(barcode, book.key)
    }

    const topics =
      book.subjectCatalogKey === null ? undefined : topicsBySubject.get(book.subjectCatalogKey)
    if (book.subjectCatalogKey !== null && topics === undefined) {
      errors.push(`${at} subjectCatalogKey müfredatta yok: ${book.subjectCatalogKey}`)
    }
    if (book.totalUnits !== null && (!Number.isInteger(book.totalUnits) || book.totalUnits < 1)) {
      errors.push(`${at} totalUnits pozitif tam sayı olmalı`)
    }

    let previousOrder = 0
    const orders = new Set<number>()
    for (const section of book.sections) {
      const sat = `${at} bölüm #${section.order}`
      if (section.title.trim() === '') errors.push(`${sat} başlık boş`)
      if (orders.has(section.order)) errors.push(`${sat} order benzersiz değil`)
      else if (section.order <= previousOrder) errors.push(`${sat} order artan sırada değil`)
      orders.add(section.order)
      previousOrder = Math.max(previousOrder, section.order)

      if (section.topicCatalogKey !== null && !(topics?.has(section.topicCatalogKey) ?? false)) {
        errors.push(`${sat} topicCatalogKey kitabın dersine ait değil: ${section.topicCatalogKey}`)
      }
      const { startUnit, endUnit } = section
      if (startUnit !== null && endUnit !== null && startUnit > endUnit) {
        errors.push(`${sat} startUnit > endUnit`)
      }
      if (book.totalUnits !== null) {
        if (startUnit !== null && startUnit > book.totalUnits) {
          errors.push(`${sat} startUnit totalUnits'i aşıyor`)
        }
        if (endUnit !== null && endUnit > book.totalUnits) {
          errors.push(`${sat} endUnit totalUnits'i aşıyor`)
        }
      }
    }
  }
  return errors
}
