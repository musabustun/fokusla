/// <reference types="node" />
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { bookLibrary } from './books'
import { toIosLibraryJson } from './iosExport'
import { fixtureBook } from './fixtures'

const jsonPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../../ios/FokusKit/Sources/FokusData/Resources/book-library.json',
)

describe('iOS kitap kütüphanesi dışa aktarımı', () => {
  it('commit edilen book-library.json web kataloğuyla aynı (drift koruması)', () => {
    const committed: unknown = JSON.parse(readFileSync(jsonPath, 'utf8'))
    expect(committed).toEqual(toIosLibraryJson(bookLibrary))
  })

  it('kitap ve bölüm anahtar sırası kararlıdır', () => {
    const [book] = toIosLibraryJson({
      version: 1,
      updatedAt: '2026-01-01',
      books: [fixtureBook()],
    }).books
    expect(Object.keys(book ?? {})).toEqual([
      'key',
      'barcodes',
      'title',
      'publisher',
      'kind',
      'exam',
      'subjectCatalogKey',
      'unit',
      'totalUnits',
      'editionYear',
      'sections',
    ])
    expect(Object.keys(book?.sections[0] ?? {})).toEqual([
      'title',
      'order',
      'startUnit',
      'endUnit',
      'topicCatalogKey',
    ])
  })
})
