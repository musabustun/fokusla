import { describe, expect, it } from 'vitest'
import { isbn10ToEan13, isValidEan13, normalizeBarcode } from './barcode'

// Vaka adları Swift `BarcodeTests` ile birebir aynıdır. Numaralar sentetiktir, gerçek ürün değildir;
// sağlama basamakları elle hesaplanmıştır.
const NORMALIZE_CASES: { name: string; input: string; expected: string | null }[] = [
  { name: 'geçerli EAN-13 aynen', input: '9781234567897', expected: '9781234567897' },
  { name: 'sıfırlı EAN-13', input: '9780000000002', expected: '9780000000002' },
  { name: 'tireli EAN-13', input: '978-1-23-456789-7', expected: '9781234567897' },
  { name: 'boşluklu EAN-13', input: ' 978 1234 5678 97 ', expected: '9781234567897' },
  { name: 'ISBN-10 X sağlamalı', input: '123456789X', expected: '9781234567897' },
  { name: 'ISBN-10 küçük x', input: '123456789x', expected: '9781234567897' },
  { name: 'ISBN-10 rakam sağlamalı', input: '0000000019', expected: '9780000000019' },
  { name: 'ISBN-10 tireli', input: '1-234-56789-X', expected: '9781234567897' },
  { name: 'UPC-A öne 0 eklenir', input: '012345678905', expected: '0012345678905' },
  { name: 'EAN-13 sağlaması yanlış', input: '9781234567890', expected: null },
  { name: 'ISBN-10 sağlaması yanlış', input: '1234567890', expected: null },
  { name: 'UPC-A sağlaması yanlış', input: '978123456789', expected: null },
  { name: 'boş metin', input: '', expected: null },
  { name: 'yalnızca ayırıcılar', input: ' - - ', expected: null },
  { name: 'harf içeren 13 karakter', input: '97812345678AB', expected: null },
  { name: 'harf içeren 12 karakter', input: '97812345678A', expected: null },
  { name: 'X ortada ISBN-10', input: '12345X7890', expected: null },
  { name: '14 hane', input: '97812345678970', expected: null },
  { name: '9 hane', input: '123456789', expected: null },
]

describe('normalizeBarcode', () => {
  it.each(NORMALIZE_CASES)('$name', ({ input, expected }) => {
    expect(normalizeBarcode(input)).toBe(expected)
  })
})

const EAN_CASES: { name: string; input: string; expected: boolean }[] = [
  { name: 'ean geçerli', input: '9781234567897', expected: true },
  { name: 'ean yanlış sağlama', input: '9781234567898', expected: false },
  { name: 'ean kısa', input: '978123456789', expected: false },
  { name: 'ean harf', input: '978123456789X', expected: false },
]

describe('isValidEan13', () => {
  it.each(EAN_CASES)('$name', ({ input, expected }) => {
    expect(isValidEan13(input)).toBe(expected)
  })
})

const ISBN10_CASES: { name: string; input: string; expected: string | null }[] = [
  { name: 'isbn10 X', input: '123456789X', expected: '9781234567897' },
  { name: 'isbn10 sıfırlar', input: '0000000000', expected: '9780000000002' },
  { name: 'isbn10 yanlış sağlama', input: '1234567890', expected: null },
  { name: 'isbn10 kısa', input: '12345', expected: null },
]

describe('isbn10ToEan13', () => {
  it.each(ISBN10_CASES)('$name', ({ input, expected }) => {
    expect(isbn10ToEan13(input)).toBe(expected)
  })
})
