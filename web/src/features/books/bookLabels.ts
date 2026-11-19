/** Kitap modülünün Türkçe etiketleri ve biçimlendiricileri (saf; React yok). */
import type { BookKind, BookUnit } from '@/domain'
import type { BookStatus } from '@/domain/calc/books'

export const BOOK_KIND_LABELS: Readonly<Record<BookKind, string>> = {
  questionBank: 'Soru bankası',
  lecture: 'Konu anlatımı',
  practiceExam: 'Deneme',
  other: 'Diğer',
}

/** Formdaki sıralama. */
export const BOOK_KINDS: readonly BookKind[] = ['questionBank', 'lecture', 'practiceExam', 'other']

/** Birim adı (tekil, büyük harfle): "Test 34", "Sayfa 210", "Bölüm 3". */
export const BOOK_UNIT_LABELS: Readonly<Record<BookUnit, string>> = {
  test: 'Test',
  page: 'Sayfa',
  section: 'Bölüm',
}

/** Birim adı (küçük harf, sayı sonrası): "12 test", "210 sayfa". */
export const BOOK_UNIT_NOUNS: Readonly<Record<BookUnit, string>> = {
  test: 'test',
  page: 'sayfa',
  section: 'bölüm',
}

export const BOOK_UNITS: readonly BookUnit[] = ['test', 'page', 'section']

export const BOOK_STATUS_LABELS: Readonly<Record<BookStatus, string>> = {
  notStarted: 'Başlanmadı',
  inProgress: 'Devam ediyor',
  completed: 'Tamamlandı',
  archived: 'Arşivlendi',
}

const NUMBER = new Intl.NumberFormat('tr-TR')
const PERCENT = new Intl.NumberFormat('tr-TR', { style: 'percent', maximumFractionDigits: 0 })
const DATE = new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'long' })
const DATE_WITH_YEAR = new Intl.DateTimeFormat('tr-TR', {
  day: 'numeric',
  month: 'long',
  year: 'numeric',
})

export function formatNumber(value: number): string {
  return NUMBER.format(value)
}

/** 0.456 → "%46". */
export function formatPercent(ratio: number): string {
  return PERCENT.format(ratio)
}

/** "Test 34" / "Sayfa 210". */
export function formatPosition(unit: BookUnit, reached: number): string {
  return `${BOOK_UNIT_LABELS[unit]} ${formatNumber(reached)}`
}

/** "34 / 120 test" ya da toplam yoksa "34 test". */
export function formatProgressCount(unit: BookUnit, reached: number, total: number | null): string {
  const noun = BOOK_UNIT_NOUNS[unit]
  if (total === null || total <= 0) return `${formatNumber(reached)} ${noun}`
  return `${formatNumber(reached)} / ${formatNumber(total)} ${noun}`
}

/** "haftada ~12 test"; hız null ise null. */
export function formatPace(unit: BookUnit, pacePerWeek: number | null): string | null {
  if (pacePerWeek === null) return null
  return `haftada ~${formatNumber(Math.round(pacePerWeek))} ${BOOK_UNIT_NOUNS[unit]}`
}

/** "19 Kasım" (bu yıl) ya da "19 Kasım 2025". */
export function formatDay(date: Date, now: Date): string {
  return date.getFullYear() === now.getFullYear() ? DATE.format(date) : DATE_WITH_YEAR.format(date)
}

/** `now`'dan `days` gün sonraki tarih (yerel gün). */
export function addDays(now: Date, days: number): Date {
  const result = new Date(now.getTime())
  result.setDate(result.getDate() + days)
  return result
}
