/**
 * Kitap formundaki "Kütüphanede ara" akışı: barkodu normalize eder, kullanıcının kitaplığında
 * ve gömülü kütüphanede arar. Sonuç `lookup` durumunda tutulur; barkod metni değişince sıfırlanır.
 */
import { useCallback, useState } from 'react'
import { useServices } from '@/data'
import { normalizeBarcode, type Book, type UUID } from '@/domain'
import {
  findLibraryBook,
  resolveLibraryBook,
  type BookLibrary,
  type ResolvedLibraryBook,
} from '@/library'
import { INVALID_BARCODE_MESSAGE } from './bookActions'

export type BarcodeLookup =
  | { status: 'idle' }
  | { status: 'invalid'; message: string }
  | { status: 'owned'; book: Book }
  | { status: 'notFound' }
  | { status: 'found'; barcode: string; resolved: ResolvedLibraryBook }

const IDLE: BarcodeLookup = { status: 'idle' }

interface Options {
  library: BookLibrary
  /** Düzenlenen kitap; kendi barkoduyla "zaten kitaplığında" demesin. */
  selfId: UUID | undefined
}

export function useBarcodeLookup({ library, selfId }: Options) {
  const { repositories } = useServices()
  const [lookup, setLookup] = useState<BarcodeLookup>(IDLE)

  const reset = useCallback(() => setLookup(IDLE), [])

  /** Sonucu döndürür ve durumu günceller. */
  const search = useCallback(
    async (raw: string): Promise<BarcodeLookup> => {
      const barcode = normalizeBarcode(raw)
      let result: BarcodeLookup
      if (barcode === null) {
        result = { status: 'invalid', message: INVALID_BARCODE_MESSAGE }
      } else {
        const owned = (await repositories.books.findByBarcode(barcode)).find(
          (book) => book.id !== selfId,
        )
        const entry = owned ? null : findLibraryBook(library, barcode)
        if (owned) result = { status: 'owned', book: owned }
        else if (entry) {
          result = { status: 'found', barcode, resolved: await resolveLibraryBook(entry, barcode) }
        } else result = { status: 'notFound' }
      }
      setLookup(result)
      return result
    },
    [library, repositories, selfId],
  )

  return { lookup, search, reset }
}
