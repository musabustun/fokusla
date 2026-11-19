/** Kitap ilerleme hesapları — SAF fonksiyonlar. Sahibi: books feature oturumu. */
import type { Book, BookProgress } from '../types'
import { NotImplementedError } from './notImplemented'

/** En son ilerleme kaydı (recordedAt'e göre); yoksa undefined. */
export function latestProgress(_entries: readonly BookProgress[]): BookProgress | undefined {
  throw new NotImplementedError('latestProgress')
}

/** İlerleme oranı (0–1). totalUnits bilinmiyorsa null. */
export function progressRatio(_book: Book, _latest: BookProgress | undefined): number | null {
  throw new NotImplementedError('progressRatio')
}
