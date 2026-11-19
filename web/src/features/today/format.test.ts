import { describe, expect, it } from 'vitest'
import { formatClock, formatDuration, formatInteger, formatNet, formatPercent } from './format'

const SECOND = 1000
const MINUTE = 60 * SECOND
const HOUR = 60 * MINUTE

describe('formatClock', () => {
  it.each([
    [0, '00:00'],
    [-5 * SECOND, '00:00'],
    [Number.NaN, '00:00'],
    [5 * MINUTE + 9 * SECOND + 999, '05:09'],
    [HOUR + 5 * MINUTE + 9 * SECOND, '1:05:09'],
  ])('%d ms → %s', (ms, expected) => {
    expect(formatClock(ms)).toBe(expected)
  })
})

describe('formatDuration', () => {
  it.each([
    [0, '0 dk'],
    [59 * SECOND, '0 dk'],
    [25 * MINUTE + 59 * SECOND, '25 dk'],
    [HOUR, '1 sa'],
    [HOUR + 5 * MINUTE, '1 sa 5 dk'],
    [Number.POSITIVE_INFINITY, '0 dk'],
  ])('%d ms → %s', (ms, expected) => {
    expect(formatDuration(ms)).toBe(expected)
  })
})

describe('sayı biçimleri (tr-TR)', () => {
  it.each([
    [formatInteger(1250), '1.250'],
    [formatInteger(0), '0'],
    [formatNet(12.75), '12,75'],
    [formatNet(-0), '0'],
    [formatNet(-1.25), '-1,25'],
    [formatPercent(0.42), '%42'],
    [formatPercent(Number.NaN), '%0'],
  ])('%s === %s', (actual, expected) => {
    expect(actual).toBe(expected)
  })
})
