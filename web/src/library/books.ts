/**
 * Gömülü kitap kataloğu. Kitaplar bakımcı tarafından kitap ELDE tutularak eklenir
 * (bkz. README.md); başlangıçta boştur.
 */
import type { BookLibrary } from './types'

export const bookLibrary: BookLibrary = {
  version: 1,
  updatedAt: '2026-11-23',
  books: [],
}
