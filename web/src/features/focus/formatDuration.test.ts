import { describe, expect, it } from 'vitest'
import { formatClock, formatDurationText } from './formatDuration'

const SECOND = 1000
const MINUTE = 60 * SECOND
const HOUR = 60 * MINUTE

describe('formatClock', () => {
  it.each([
    [0, '00:00'],
    [999, '00:00'],
    [SECOND, '00:01'],
    [5 * MINUTE + 9 * SECOND, '05:09'],
    [5 * MINUTE + 9 * SECOND + 999, '05:09'],
    [59 * MINUTE + 59 * SECOND, '59:59'],
    [HOUR, '1:00:00'],
    [HOUR + 5 * MINUTE + 9 * SECOND, '1:05:09'],
    [12 * HOUR + 34 * MINUTE + 56 * SECOND, '12:34:56'],
    [-5 * SECOND, '00:00'],
    [Number.NaN, '00:00'],
  ])('%d ms → %s', (ms, expected) => {
    expect(formatClock(ms)).toBe(expected)
  })
})

describe('formatDurationText', () => {
  it.each([
    [0, '0 sn'],
    [45 * SECOND, '45 sn'],
    [59 * SECOND + 999, '59 sn'],
    [MINUTE, '1 dk'],
    [25 * MINUTE, '25 dk'],
    [25 * MINUTE + 59 * SECOND, '25 dk'],
    [59 * MINUTE + 59 * SECOND, '59 dk'],
    [HOUR, '1 sa'],
    [HOUR + 5 * MINUTE, '1 sa 5 dk'],
    [HOUR + 5 * MINUTE + 30 * SECOND, '1 sa 5 dk'],
    [26 * HOUR, '26 sa'],
    [-MINUTE, '0 sn'],
    [Number.POSITIVE_INFINITY, '0 sn'],
  ])('%d ms → %s', (ms, expected) => {
    expect(formatDurationText(ms)).toBe(expected)
  })
})
