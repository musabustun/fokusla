import { describe, expect, it } from 'vitest'
import { formatDayLabel, formatSessionStart, formatWeekdayShort, parseISODate } from './formatDate'

describe('formatDate', () => {
  it('parses an ISO date as local midnight', () => {
    const date = parseISODate('2026-11-19')
    expect([date.getFullYear(), date.getMonth(), date.getDate(), date.getHours()]).toEqual([
      2026, 10, 19, 0,
    ])
  })

  it('formats Turkish weekday and day labels', () => {
    expect(formatWeekdayShort('2026-11-18')).toBe('Çar')
    expect(formatDayLabel('2026-11-18')).toBe('Çar 18 Kas')
  })

  it('formats a session start with date and time', () => {
    expect(formatSessionStart(new Date(2026, 10, 19, 14, 5))).toBe('19 Kas Per, 14:05')
  })
})
