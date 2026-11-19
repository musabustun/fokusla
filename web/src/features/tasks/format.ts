/**
 * Görevler ekranının Türkçe metin biçimlendiricileri (saf). Tarih/gün adları Intl tr-TR'den,
 * saat diliminden bağımsız olsun diye sabit UTC tarihler üzerinden türetilir.
 */
import type { ISODate, RecurrenceRule, Weekday } from '@/domain'

export const WEEKDAYS: readonly Weekday[] = [1, 2, 3, 4, 5, 6, 7]

const WEEKDAY_SHORT = new Intl.DateTimeFormat('tr-TR', { weekday: 'short', timeZone: 'UTC' })
const WEEKDAY_LONG = new Intl.DateTimeFormat('tr-TR', { weekday: 'long', timeZone: 'UTC' })
const DAY_TITLE = new Intl.DateTimeFormat('tr-TR', {
  day: 'numeric',
  month: 'long',
  weekday: 'long',
  timeZone: 'UTC',
})
const LONG_DATE = new Intl.DateTimeFormat('tr-TR', {
  day: 'numeric',
  month: 'long',
  year: 'numeric',
  timeZone: 'UTC',
})
const NUMBER = new Intl.NumberFormat('tr-TR')
const PERCENT = new Intl.NumberFormat('tr-TR', { style: 'percent', maximumFractionDigits: 0 })

/** 2024-01-01 bir Pazartesi'dir; `weekday` (1–7) için o haftanın UTC tarihi. */
function weekdayDate(weekday: Weekday): Date {
  return new Date(Date.UTC(2024, 0, weekday))
}

/** ISODate → aynı takvim gününün UTC gece yarısı. */
function utcDate(day: ISODate): Date {
  const [year = 0, month = 1, date = 1] = day.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, date))
}

/** Kısa gün adı: "Pzt", "Sal", … */
export function weekdayShortName(weekday: Weekday): string {
  return WEEKDAY_SHORT.format(weekdayDate(weekday))
}

/** Tam gün adı: "Pazartesi", … */
export function weekdayLongName(weekday: Weekday): string {
  return WEEKDAY_LONG.format(weekdayDate(weekday))
}

const WEEKDAY_SET = [1, 2, 3, 4, 5]
const WEEKEND_SET = [6, 7]

function sameDays(a: readonly number[], b: readonly number[]): boolean {
  return a.length === b.length && a.every((value, index) => value === b[index])
}

/** Tekrar kuralı metni: "Her gün", "Hafta içi", "Hafta sonu" ya da "Pzt, Çar, Cum". */
export function recurrenceText(rule: RecurrenceRule): string {
  if (rule.frequency === 'daily') return 'Her gün'
  const days = [...new Set(rule.weekdays)].sort((a, b) => a - b)
  if (days.length === 0) return 'Gün seçilmedi'
  if (days.length === 7) return 'Her gün'
  if (sameDays(days, WEEKDAY_SET)) return 'Hafta içi'
  if (sameDays(days, WEEKEND_SET)) return 'Hafta sonu'
  return days.map(weekdayShortName).join(', ')
}

/** Ekran alt başlığı: "19 Kasım Perşembe". */
export function formatDayTitle(day: ISODate): string {
  return DAY_TITLE.format(utcDate(day))
}

/** Uzun tarih: "19 Kasım 2026". */
export function formatLongDate(day: ISODate): string {
  return LONG_DATE.format(utcDate(day))
}

export function formatNumber(value: number): string {
  return NUMBER.format(value)
}

/** 0–1 oran → "%57". */
export function formatPercent(rate: number): string {
  return PERCENT.format(rate)
}

/** Son tarihe kalan gün → "Bugün", "Yarın", "2 gün kaldı", "Dün", "3 gün gecikti". */
export function dueText(daysUntil: number): string {
  if (daysUntil === 0) return 'Bugün'
  if (daysUntil === 1) return 'Yarın'
  if (daysUntil === -1) return 'Dün'
  if (daysUntil > 1) return `${formatNumber(daysUntil)} gün kaldı`
  return `${formatNumber(-daysUntil)} gün gecikti`
}

/**
 * Hedef/gerçekleşen miktar: "50 soru", "42/50 soru", "42 soru" (hedefsiz), "50".
 * İkisi de yoksa null.
 */
export function quantityText(
  target: number | null | undefined,
  actual: number | null | undefined,
  unit: string | null | undefined,
): string | null {
  const hasTarget = target !== null && target !== undefined
  const hasActual = actual !== null && actual !== undefined
  if (!hasTarget && !hasActual) return null
  const amount =
    hasTarget && hasActual
      ? `${formatNumber(actual)}/${formatNumber(target)}`
      : formatNumber(actual ?? target ?? 0)
  const trimmedUnit = unit?.trim()
  return trimmedUnit ? `${amount} ${trimmedUnit}` : amount
}

/** Seri metni: "3 gün seri". */
export function streakText(days: number): string {
  return `${formatNumber(days)} gün seri`
}
