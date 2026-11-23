import { describe, expect, it } from 'vitest'
import type { BookUnit } from '@/domain'
import { formatSectionRange } from './bookLabels'

describe('formatSectionRange', () => {
  it.each<[BookUnit, number | null, number | null, string | null]>([
    ['test', 1, 12, 'Test 1–12'],
    ['page', 10, 40, 'Sayfa 10–40'],
    ['section', 3, 3, 'Bölüm 3'],
    ['test', 5, null, 'Test 5'],
    ['page', null, 80, 'Sayfa 80'],
    ['page', 1000, 1200, 'Sayfa 1.000–1.200'],
    ['test', null, null, null],
  ])('%s %s–%s → %s', (unit, start, end, expected) => {
    expect(formatSectionRange(unit, start, end)).toBe(expected)
  })
})
