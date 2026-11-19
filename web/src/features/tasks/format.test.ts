import { describe, expect, it } from 'vitest'
import type { RecurrenceRule, Weekday } from '@/domain'
import {
  dueText,
  formatDayTitle,
  formatLongDate,
  formatNumber,
  formatPercent,
  quantityText,
  recurrenceText,
  streakText,
  weekdayLongName,
  weekdayShortName,
  WEEKDAYS,
} from './format'

describe('gün adları', () => {
  it.each([
    [1, 'Pzt', 'Pazartesi'],
    [2, 'Sal', 'Salı'],
    [3, 'Çar', 'Çarşamba'],
    [4, 'Per', 'Perşembe'],
    [5, 'Cum', 'Cuma'],
    [6, 'Cmt', 'Cumartesi'],
    [7, 'Paz', 'Pazar'],
  ] as const)('%i → %s / %s', (weekday, short, long) => {
    expect(weekdayShortName(weekday)).toBe(short)
    expect(weekdayLongName(weekday)).toBe(long)
  })

  it('WEEKDAYS Pazartesi→Pazar sıralıdır', () => {
    expect(WEEKDAYS).toEqual([1, 2, 3, 4, 5, 6, 7])
  })
})

describe('recurrenceText', () => {
  const weekly = (weekdays: Weekday[]): RecurrenceRule => ({ frequency: 'weekly', weekdays })

  it.each<[RecurrenceRule, string]>([
    [{ frequency: 'daily', weekdays: [] }, 'Her gün'],
    [weekly([1, 2, 3, 4, 5]), 'Hafta içi'],
    [weekly([5, 4, 3, 2, 1]), 'Hafta içi'],
    [weekly([6, 7]), 'Hafta sonu'],
    [weekly([1, 2, 3, 4, 5, 6, 7]), 'Her gün'],
    [weekly([1, 3, 5]), 'Pzt, Çar, Cum'],
    [weekly([7, 1, 1]), 'Pzt, Paz'],
    [weekly([]), 'Gün seçilmedi'],
  ])('%j → %s', (rule, expected) => {
    expect(recurrenceText(rule)).toBe(expected)
  })
})

describe('tarih biçimleri', () => {
  it.each([
    ['2026-11-19', '19 Kasım Perşembe', '19 Kasım 2026'],
    ['2026-01-01', '1 Ocak Perşembe', '1 Ocak 2026'],
    ['2028-02-29', '29 Şubat Salı', '29 Şubat 2028'],
  ])('%s', (day, title, long) => {
    expect(formatDayTitle(day)).toBe(title)
    expect(formatLongDate(day)).toBe(long)
  })
})

describe('dueText', () => {
  it.each([
    [0, 'Bugün'],
    [1, 'Yarın'],
    [2, '2 gün kaldı'],
    [1500, '1.500 gün kaldı'],
    [-1, 'Dün'],
    [-3, '3 gün gecikti'],
  ])('%i → %s', (days, expected) => {
    expect(dueText(days)).toBe(expected)
  })
})

describe('quantityText', () => {
  it.each([
    [50, null, 'soru', '50 soru'],
    [50, 42, 'soru', '42/50 soru'],
    [null, 42, 'sayfa', '42 sayfa'],
    [50, undefined, null, '50'],
    [1000, 1200, '  soru ', '1.200/1.000 soru'],
    [null, null, 'soru', null],
    [undefined, undefined, undefined, null],
  ] as const)('%s / %s %s → %s', (target, actual, unit, expected) => {
    expect(quantityText(target, actual, unit)).toBe(expected)
  })
})

describe('sayılar', () => {
  it('tr-TR biçimini kullanır', () => {
    expect(formatNumber(12345)).toBe('12.345')
    expect(formatPercent(0.571)).toBe('%57')
    expect(formatPercent(1)).toBe('%100')
    expect(streakText(3)).toBe('3 gün seri')
  })
})
