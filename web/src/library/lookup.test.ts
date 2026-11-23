import { describe, expect, it } from 'vitest'
import { catalogEntityId } from '@/domain'
import { fixtureBook } from './fixtures'
import { findLibraryBook, resolveLibraryBook } from './lookup'
import type { BookLibrary } from './types'

const library: BookLibrary = {
  version: 1,
  updatedAt: '2026-11-23',
  books: [
    fixtureBook(),
    fixtureBook({
      key: 'ornek-yayinlari-ayt-fizik',
      barcodes: ['9780000000002', '9780000000019'],
      title: 'Örnek Yayınları AYT Fizik',
      subjectCatalogKey: null,
      sections: [],
    }),
  ],
}

describe('findLibraryBook', () => {
  it.each([
    ['EAN-13', '9781234567897', 'ornek-yayinlari-tyt-matematik-soru-bankasi'],
    ['tireli', '978-1-23-456789-7', 'ornek-yayinlari-tyt-matematik-soru-bankasi'],
    ['ISBN-10', '123456789X', 'ornek-yayinlari-tyt-matematik-soru-bankasi'],
    ['ikinci barkod', '9780000000019', 'ornek-yayinlari-ayt-fizik'],
    ['ISBN-10 ikinci', '0000000019', 'ornek-yayinlari-ayt-fizik'],
  ])('%s ile bulur', (_name, raw, key) => {
    expect(findLibraryBook(library, raw)?.key).toBe(key)
  })

  it.each([
    ['katalogda yok', '9780000000026'],
    ['geçersiz sağlama', '9781234567890'],
    ['boş', ''],
  ])('%s → null', (_name, raw) => {
    expect(findLibraryBook(library, raw)).toBeNull()
  })

  it('boş katalogda null', () => {
    expect(
      findLibraryBook({ version: 1, updatedAt: '2026-11-23', books: [] }, '9781234567897'),
    ).toBeNull()
  })
})

describe('resolveLibraryBook', () => {
  it('ders ve konu anahtarlarını catalogEntityId ile UUID yapar', async () => {
    const resolved = await resolveLibraryBook(fixtureBook(), '123456789X')
    expect(resolved.libraryKey).toBe('ornek-yayinlari-tyt-matematik-soru-bankasi')
    expect(resolved.barcode).toBe('9781234567897')
    expect(resolved.subjectId).toBe(await catalogEntityId('tyt-matematik'))
    expect(resolved.sections[0]?.topicId).toBe(
      await catalogEntityId('tyt-matematik.temel-kavramlar'),
    )
    expect(resolved.sections[1]?.topicId).toBeNull()
    expect(resolved.unit).toBe('test')
    expect(resolved.totalUnits).toBe(40)
  })

  it('barkod verilmezse alan yoktur; ders yoksa subjectId null', async () => {
    const resolved = await resolveLibraryBook(fixtureBook({ subjectCatalogKey: null }))
    expect('barcode' in resolved).toBe(false)
    expect(resolved.subjectId).toBeNull()
  })

  it('geçersiz barkod verilirse barkod alanı eklenmez', async () => {
    const resolved = await resolveLibraryBook(fixtureBook(), 'abc')
    expect('barcode' in resolved).toBe(false)
  })
})
