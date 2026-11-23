/** Yalnızca testler için sentetik kitap (gerçek ürün değildir). */
import type { LibraryBook } from './types'

export function fixtureBook(overrides: Partial<LibraryBook> = {}): LibraryBook {
  return {
    key: 'ornek-yayinlari-tyt-matematik-soru-bankasi',
    barcodes: ['9781234567897'],
    title: 'Örnek Yayınları TYT Matematik Soru Bankası',
    publisher: 'Örnek Yayınları',
    kind: 'questionBank',
    exam: 'TYT',
    subjectCatalogKey: 'tyt-matematik',
    unit: 'test',
    totalUnits: 40,
    editionYear: 2026,
    sections: [
      {
        title: 'Temel Kavramlar',
        order: 1,
        startUnit: 1,
        endUnit: 10,
        topicCatalogKey: 'tyt-matematik.temel-kavramlar',
      },
      { title: 'Karma', order: 2, startUnit: 11, endUnit: 40, topicCatalogKey: null },
    ],
    ...overrides,
  }
}
