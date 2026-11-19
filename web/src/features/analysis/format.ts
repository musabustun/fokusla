/** Analiz modülünün Türkçe (tr-TR) sayı/tarih biçimleyicileri. */
import type { ISODate, ISODateTime } from '@/domain'

const NET_FORMAT = new Intl.NumberFormat('tr-TR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})
const PERCENT_FORMAT = new Intl.NumberFormat('tr-TR', {
  style: 'percent',
  maximumFractionDigits: 0,
})
const COUNT_FORMAT = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 })
const DATE_FORMAT = new Intl.DateTimeFormat('tr-TR', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
})
const SHORT_DATE_FORMAT = new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'short' })

/** Net, her zaman iki ondalıkla: 12,75 · −1,25 · 8,00. */
export function formatNet(net: number): string {
  return NET_FORMAT.format(net === 0 ? 0 : net)
}

/** Oran (0–1) → "%75". */
export function formatPercent(ratio: number): string {
  return PERCENT_FORMAT.format(Number.isFinite(ratio) ? ratio : 0)
}

/** Tam sayı → "1.240". */
export function formatCount(count: number): string {
  return COUNT_FORMAT.format(count)
}

/** Anlık zaman → yerel gün, ör. "19 Kas 2026". */
export function formatDateTime(value: ISODateTime): string {
  return DATE_FORMAT.format(new Date(value))
}

/** Yerel takvim günü (YYYY-MM-DD) → kısa gün, ör. "19 Kas". Saat dilimi kaymasın diye yerel öğlen. */
export function formatShortDay(day: ISODate): string {
  const [y, m, d] = day.split('-').map(Number)
  return SHORT_DATE_FORMAT.format(new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1, 12))
}

/** Anlık zaman → kısa yerel gün, ör. "19 Kas". */
export function formatShortDateTime(value: ISODateTime): string {
  return SHORT_DATE_FORMAT.format(new Date(value))
}

/** Soru sayısı, ör. "24 soru". */
export function formatQuestionCount(count: number): string {
  return `${formatCount(count)} soru`
}

/** Net değeri birimiyle, ör. "12,75 net". */
export function formatNetValue(net: number): string {
  return `${formatNet(net)} net`
}

/** Doğru/yanlış/boş kısaltması, ör. "12D 4Y 4B". */
export function formatAnswerCounts(counts: {
  correct: number
  wrong: number
  blank: number
}): string {
  return `${formatCount(counts.correct)}D ${formatCount(counts.wrong)}Y ${formatCount(counts.blank)}B`
}
