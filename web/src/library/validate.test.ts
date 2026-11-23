import { describe, expect, it } from 'vitest'
import { yksCurriculum } from '@/curriculum'
import { bookLibrary } from './books'
import { fixtureBook } from './fixtures'
import type { BookLibrary, LibraryBook, LibrarySection } from './types'
import { validateLibrary } from './validate'

const lib = (books: LibraryBook[], over: Partial<BookLibrary> = {}): BookLibrary => ({
  version: 1,
  updatedAt: '2026-11-23',
  books,
  ...over,
})
const section = (over: Partial<LibrarySection>): LibrarySection => ({
  title: 'Bölüm',
  order: 1,
  startUnit: null,
  endUnit: null,
  topicCatalogKey: null,
  ...over,
})
const errorsOf = (books: LibraryBook[], over: Partial<BookLibrary> = {}) =>
  validateLibrary(lib(books, over), yksCurriculum).join('\n')

describe('validateLibrary', () => {
  it('gerçek bookLibrary hatasız', () => {
    expect(validateLibrary(bookLibrary, yksCurriculum)).toEqual([])
  })

  it('geçerli fixture hatasız, boş katalog hatasız', () => {
    expect(validateLibrary(lib([fixtureBook()]), yksCurriculum)).toEqual([])
    expect(validateLibrary(lib([]), yksCurriculum)).toEqual([])
  })

  it.each<[string, () => string, string]>([
    ['version', () => errorsOf([], { version: 0 }), 'version'],
    ['updatedAt', () => errorsOf([], { updatedAt: '23.11.2026' }), 'updatedAt'],
    ['boş key', () => errorsOf([fixtureBook({ key: ' ' })]), 'boş key'],
    [
      'yinelenen key',
      () => errorsOf([fixtureBook(), fixtureBook({ barcodes: ['9780000000002'] })]),
      'key benzersiz değil',
    ],
    ['boş başlık', () => errorsOf([fixtureBook({ title: '' })]), 'başlık boş'],
    ['barkod yok', () => errorsOf([fixtureBook({ barcodes: [] })]), 'en az bir barkod'],
    [
      'geçersiz barkod',
      () => errorsOf([fixtureBook({ barcodes: ['9781234567890'] })]),
      'barkod geçersiz',
    ],
    [
      'ISBN-10 normalleşmemiş',
      () => errorsOf([fixtureBook({ barcodes: ['123456789X'] })]),
      'normalleştirilmemiş',
    ],
    ['yinelenen barkod', () => errorsOf([fixtureBook(), fixtureBook({ key: 'baska' })]), 'zaten'],
    [
      'bilinmeyen ders',
      () => errorsOf([fixtureBook({ subjectCatalogKey: 'yok' })]),
      'müfredatta yok',
    ],
    ['totalUnits', () => errorsOf([fixtureBook({ totalUnits: 0 })]), 'totalUnits pozitif'],
    [
      'başka dersin konusu',
      () =>
        errorsOf([
          fixtureBook({ sections: [section({ topicCatalogKey: 'tyt-turkce.sozcukte-anlam' })] }),
        ]),
      'kitabın dersine ait değil',
    ],
    [
      'derssiz kitapta konu',
      () =>
        errorsOf([
          fixtureBook({
            subjectCatalogKey: null,
            sections: [section({ topicCatalogKey: 'tyt-matematik.temel-kavramlar' })],
          }),
        ]),
      'kitabın dersine ait değil',
    ],
    [
      'boş bölüm başlığı',
      () => errorsOf([fixtureBook({ sections: [section({ title: '' })] })]),
      'başlık boş',
    ],
    [
      'yinelenen order',
      () => errorsOf([fixtureBook({ sections: [section({}), section({})] })]),
      'order benzersiz değil',
    ],
    [
      'sırasız order',
      () => errorsOf([fixtureBook({ sections: [section({ order: 2 }), section({ order: 1 })] })]),
      'artan sırada değil',
    ],
    [
      'start > end',
      () => errorsOf([fixtureBook({ sections: [section({ startUnit: 9, endUnit: 3 })] })]),
      'startUnit > endUnit',
    ],
    [
      'start > total',
      () => errorsOf([fixtureBook({ sections: [section({ startUnit: 41 })] })]),
      "startUnit totalUnits'i aşıyor",
    ],
    [
      'end > total',
      () => errorsOf([fixtureBook({ sections: [section({ endUnit: 41 })] })]),
      "endUnit totalUnits'i aşıyor",
    ],
  ])('%s hatası bulunur', (_name, run, expected) => {
    expect(run()).toContain(expected)
  })

  it('totalUnits null iken üst sınır denetlenmez', () => {
    const book = fixtureBook({
      totalUnits: null,
      sections: [section({ startUnit: 1, endUnit: 999 })],
    })
    expect(validateLibrary(lib([book]), yksCurriculum)).toEqual([])
  })
})
