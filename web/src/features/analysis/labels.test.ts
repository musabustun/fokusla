import { describe, expect, it } from 'vitest'
import type { Book, TestResult } from '@/domain'
import type { TestSummary } from '@/domain/calc/tests'
import {
  NO_RESULTS_TEXT,
  resultSubtitle,
  resultTitle,
  subjectStatText,
  topicDetailText,
  topicStatText,
  UNKNOWN_SOURCE_TEXT,
} from './labels'

const localISO = (y: number, m: number, d: number) => new Date(y, m - 1, d, 10).toISOString()

const SUMMARY: TestSummary = {
  testCount: 2,
  totalQuestions: 24,
  correct: 15,
  wrong: 9,
  blank: 0,
  net: 12.75,
  accuracy: 0.64,
  netRatio: 0.53,
  lastTakenAt: localISO(2026, 11, 19),
}
const EMPTY: TestSummary = {
  ...SUMMARY,
  testCount: 0,
  totalQuestions: 0,
  net: 0,
  accuracy: 0,
  lastTakenAt: null,
}

function result(patch: Partial<TestResult>): TestResult {
  return {
    id: 'r1',
    createdAt: '2026-11-19T00:00:00.000Z',
    updatedAt: '2026-11-19T00:00:00.000Z',
    deletedAt: null,
    subjectId: 's1',
    topicId: null,
    bookId: null,
    label: null,
    sourceName: null,
    takenAt: localISO(2026, 11, 19),
    correct: 12,
    wrong: 4,
    blank: 4,
    durationSeconds: null,
    note: null,
    ...patch,
  }
}

const BOOK = { id: 'b1', title: 'Karekök' } as Book
const BOOKS = new Map([[BOOK.id, BOOK]])

describe('özet metinleri', () => {
  it.each([
    [subjectStatText(SUMMARY), '12,75 net · %64'],
    [subjectStatText(undefined), NO_RESULTS_TEXT],
    [subjectStatText(EMPTY), NO_RESULTS_TEXT],
    [topicStatText(SUMMARY), '%64 · 12,75 net'],
    [topicStatText(undefined), NO_RESULTS_TEXT],
    [topicDetailText(SUMMARY), '24 soru · son 19 Kas'],
    [topicDetailText({ ...SUMMARY, lastTakenAt: null }), '24 soru'],
    [topicDetailText(EMPTY), undefined],
  ])('%s === %s', (actual, expected) => {
    expect(actual).toBe(expected)
  })
})

describe('resultTitle', () => {
  it.each([
    [{ bookId: 'b1', label: 'Test 12' }, 'Karekök · Test 12'],
    [{ bookId: 'b1' }, 'Karekök'],
    [{ bookId: 'silinmis', sourceName: 'Fasikül' }, 'Fasikül'],
    [{ sourceName: 'Okul fasikülü', label: 's. 45' }, 'Okul fasikülü · s. 45'],
    [{ sourceName: '   ', label: 'Deneme 3' }, 'Deneme 3'],
    [{ sourceName: undefined }, UNKNOWN_SOURCE_TEXT],
    [{ label: '  ' }, UNKNOWN_SOURCE_TEXT],
  ])('%o → %s', (patch, expected) => {
    expect(resultTitle(result(patch), BOOKS)).toBe(expected)
  })
})

describe('resultSubtitle', () => {
  it('tarih ve D/Y/B', () => {
    expect(resultSubtitle(result({}))).toBe('19 Kas 2026 · 12D 4Y 4B')
  })
})
