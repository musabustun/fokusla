import { describe, expect, it } from 'vitest'
import {
  formatClock,
  formatClockLabel,
  formatDurationShort,
  formatPresenceLine,
  inviteLink,
} from './format'

const MIN = 60_000

describe('formatDurationShort', () => {
  it.each([
    [0, '0 dk'],
    [1, "1 dk'dan az"],
    [59_999, "1 dk'dan az"],
    [-5, '0 dk'],
    [Number.NaN, '0 dk'],
    [MIN, '1 dk'],
    [25 * MIN + 59_000, '25 dk'],
    [60 * MIN, '1 sa 00 dk'],
    [130 * MIN, '2 sa 10 dk'],
  ])('%s ms → %s', (ms, expected) => {
    expect(formatDurationShort(ms)).toBe(expected)
  })
})

describe('formatClock', () => {
  it.each([
    [0, '00:00'],
    [-1000, '00:00'],
    [9_999, '00:09'],
    [4 * MIN + 9_000, '04:09'],
    [65 * MIN + 9_000, '1:05:09'],
  ])('%s ms → %s', (ms, expected) => {
    expect(formatClock(ms)).toBe(expected)
  })
})

describe('formatClockLabel', () => {
  it.each([
    [0, '0 saniye'],
    [65 * MIN + 9_000, '1 saat 5 dakika 9 saniye'],
    [2 * MIN, '2 dakika 0 saniye'],
  ])('%s ms → %s', (ms, expected) => {
    expect(formatClockLabel(ms)).toBe(expected)
  })
})

describe('formatPresenceLine', () => {
  it('çevrimdışıda süre göstermez', () => {
    expect(formatPresenceLine('offline', 10 * MIN)).toBe('Çevrimdışı')
  })
  it('odak ve molada süreyi ekler', () => {
    expect(formatPresenceLine('focusing', 25 * MIN)).toBe('Odakta · 25 dk')
    expect(formatPresenceLine('onBreak', 4 * MIN)).toBe('Molada · 4 dk')
  })
})

describe('inviteLink', () => {
  it('davet kodunu sorgu parametresi olarak ekler', () => {
    expect(inviteLink('http://localhost:5173', '/sosyal', 'AB2CD3')).toBe(
      'http://localhost:5173/sosyal?davet=AB2CD3',
    )
  })
})
