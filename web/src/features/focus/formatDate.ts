/** Odak ekranındaki tarih etiketleri (tr-TR, yerel saat dilimi). */
import type { ISODate } from '@/domain'

const LOCALE = 'tr-TR'

const weekdayFormat = new Intl.DateTimeFormat(LOCALE, { weekday: 'short' })
const dayMonthFormat = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short' })
const timeFormat = new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit' })

/** `YYYY-MM-DD` → yerel gece yarısı. */
export function parseISODate(day: ISODate): Date {
  const [year = 0, month = 1, date = 1] = day.split('-').map(Number)
  return new Date(year, month - 1, date)
}

/** Kısa gün adı: "Çar". */
export function formatWeekdayShort(day: ISODate): string {
  return weekdayFormat.format(parseISODate(day))
}

/** Grafik için tam gün etiketi: "Çar 19 Kas". */
export function formatDayLabel(day: ISODate): string {
  const date = parseISODate(day)
  return `${weekdayFormat.format(date)} ${dayMonthFormat.format(date)}`
}

/** Geçmiş oturum satırı: "19 Kas Çar, 14:05". */
export function formatSessionStart(date: Date): string {
  return `${dayMonthFormat.format(date)} ${weekdayFormat.format(date)}, ${timeFormat.format(date)}`
}
