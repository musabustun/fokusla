import { describe, expect, it } from 'vitest'
import {
  formatAnswerCounts,
  formatCount,
  formatDateTime,
  formatNet,
  formatNetValue,
  formatPercent,
  formatQuestionCount,
  formatShortDateTime,
  formatShortDay,
} from './format'

/** Yerel saatle oluşturulmuş anı ISO'ya çevirir (testler saat diliminden bağımsız olsun). */
const localISO = (y: number, m: number, d: number, h = 9) => new Date(y, m - 1, d, h).toISOString()

describe('formatNet', () => {
  it.each([
    [12.75, '12,75'],
    [8, '8,00'],
    [0, '0,00'],
    [-0, '0,00'],
    [-1.25, '-1,25'],
    [1240.5, '1.240,50'],
    [0.125, '0,13'],
  ])('%s → %s', (net, expected) => {
    expect(formatNet(net)).toBe(expected)
  })
})

describe('formatPercent', () => {
  it.each([
    [0.5, '%50'],
    [0.75, '%75'],
    [1, '%100'],
    [0, '%0'],
    [0.666, '%67'],
    [Number.NaN, '%0'],
    [Number.POSITIVE_INFINITY, '%0'],
  ])('%s → %s', (ratio, expected) => {
    expect(formatPercent(ratio)).toBe(expected)
  })
})

describe('sayı ve etiket biçimleri', () => {
  it.each([
    [formatCount(1240), '1.240'],
    [formatCount(7), '7'],
    [formatQuestionCount(24), '24 soru'],
    [formatQuestionCount(1500), '1.500 soru'],
    [formatNetValue(11), '11,00 net'],
    [formatNetValue(-0.5), '-0,50 net'],
    [formatAnswerCounts({ correct: 12, wrong: 4, blank: 4 }), '12D 4Y 4B'],
    [formatAnswerCounts({ correct: 0, wrong: 0, blank: 0 }), '0D 0Y 0B'],
  ])('%s === %s', (actual, expected) => {
    expect(actual).toBe(expected)
  })
})

describe('tarih biçimleri', () => {
  it.each([
    [formatDateTime(localISO(2026, 11, 19)), '19 Kas 2026'],
    [formatDateTime(localISO(2027, 1, 1, 0)), '1 Oca 2027'],
    [formatShortDateTime(localISO(2026, 11, 19, 23)), '19 Kas'],
    [formatShortDay('2026-11-19'), '19 Kas'],
    [formatShortDay('2027-06-01'), '1 Haz'],
  ])('%s === %s', (actual, expected) => {
    expect(actual).toBe(expected)
  })
})
