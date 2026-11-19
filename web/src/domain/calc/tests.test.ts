import { describe, expect, it } from 'vitest'
import type { TestResult, UUID } from '../types'
import {
  DEFAULT_WEAK_TOPIC_LIMIT,
  MIN_QUESTIONS_FOR_WEAKNESS,
  WRONG_ANSWER_PENALTY,
  accuracyOf,
  computeNet,
  dailyNetTrend,
  findWeakestTopics,
  questionCount,
  summarizeBySubject,
  summarizeByTopic,
  summarizeResults,
  type TestSummary,
} from './tests'

// ---------------------------------------------------------------------------
// Fixture yardımcıları
// ---------------------------------------------------------------------------

const SUBJECT_A: UUID = 'aaaaaaaa-0000-4000-8000-000000000001'
const SUBJECT_B: UUID = 'aaaaaaaa-0000-4000-8000-000000000002'
const TOPIC_1: UUID = 'bbbbbbbb-0000-4000-8000-000000000001'
const TOPIC_2: UUID = 'bbbbbbbb-0000-4000-8000-000000000002'
const TOPIC_3: UUID = 'bbbbbbbb-0000-4000-8000-000000000003'

let fixtureSeq = 0

function makeResult(overrides: Partial<TestResult> = {}): TestResult {
  fixtureSeq += 1
  const stamp = '2026-11-19T10:00:00.000Z'
  return {
    id: `cccccccc-0000-4000-8000-${String(fixtureSeq).padStart(12, '0')}`,
    createdAt: stamp,
    updatedAt: stamp,
    deletedAt: null,
    subjectId: SUBJECT_A,
    topicId: TOPIC_1,
    bookId: null,
    label: null,
    takenAt: stamp,
    correct: 0,
    wrong: 0,
    blank: 0,
    durationSeconds: null,
    note: null,
    ...overrides,
  }
}

/** Yerel saatle (ay 0 tabanlı) bir anın ISO UTC damgası — her saat diliminde aynı yerel günü verir. */
function localISO(year: number, monthIndex: number, day: number, hour = 12, minute = 0): string {
  return new Date(year, monthIndex, day, hour, minute).toISOString()
}

function makeSummary(overrides: Partial<TestSummary> = {}): TestSummary {
  return {
    testCount: 1,
    totalQuestions: 0,
    correct: 0,
    wrong: 0,
    blank: 0,
    net: 0,
    accuracy: 0,
    netRatio: 0,
    lastTakenAt: null,
    ...overrides,
  }
}

function deepFreeze<T>(value: T): T {
  if (value !== null && typeof value === 'object') {
    Object.freeze(value)
    for (const child of Object.values(value)) deepFreeze(child)
  }
  return value
}

// ---------------------------------------------------------------------------
// Sabitler
// ---------------------------------------------------------------------------

describe('sabitler', () => {
  it('YKS kuralları', () => {
    expect(WRONG_ANSWER_PENALTY).toBe(0.25)
    expect(MIN_QUESTIONS_FOR_WEAKNESS).toBe(20)
    expect(DEFAULT_WEAK_TOPIC_LIMIT).toBe(5)
  })
})

// ---------------------------------------------------------------------------
// Tekil sonuç hesapları
// ---------------------------------------------------------------------------

interface CountCase {
  name: string
  correct: number
  wrong: number
  blank: number
  net: number
  questions: number
  accuracy: number
}

const COUNT_CASES: CountCase[] = [
  { name: 'hiç soru yok', correct: 0, wrong: 0, blank: 0, net: 0, questions: 0, accuracy: 0 },
  { name: 'hepsi doğru', correct: 20, wrong: 0, blank: 0, net: 20, questions: 20, accuracy: 1 },
  {
    name: 'yalnızca yanlış (negatif net)',
    correct: 0,
    wrong: 6,
    blank: 0,
    net: -1.5,
    questions: 6,
    accuracy: 0,
  },
  { name: 'yalnızca boş', correct: 0, wrong: 0, blank: 10, net: 0, questions: 10, accuracy: 0 },
  {
    name: '4 yanlış 1 doğruyu götürür',
    correct: 1,
    wrong: 4,
    blank: 0,
    net: 0,
    questions: 5,
    accuracy: 0.2,
  },
  { name: 'karışık', correct: 30, wrong: 7, blank: 3, net: 28.25, questions: 40, accuracy: 0.75 },
  {
    name: 'tek yanlış çeyrek düşer',
    correct: 10,
    wrong: 1,
    blank: 9,
    net: 9.75,
    questions: 20,
    accuracy: 0.5,
  },
]

describe('computeNet', () => {
  it.each(COUNT_CASES)('$name → net $net', ({ correct, wrong, net }) => {
    expect(computeNet({ correct, wrong })).toBe(net)
  })
})

describe('questionCount', () => {
  it.each(COUNT_CASES)('$name → $questions soru', ({ correct, wrong, blank, questions }) => {
    expect(questionCount({ correct, wrong, blank })).toBe(questions)
  })
})

describe('accuracyOf', () => {
  it.each(COUNT_CASES)('$name → başarı $accuracy', ({ correct, wrong, blank, accuracy }) => {
    expect(accuracyOf({ correct, wrong, blank })).toBeCloseTo(accuracy, 10)
  })
})

// ---------------------------------------------------------------------------
// summarizeResults
// ---------------------------------------------------------------------------

type Row = Pick<TestResult, 'correct' | 'wrong' | 'blank' | 'takenAt'>

interface SummaryCase {
  name: string
  rows: Row[]
  expected: TestSummary
}

const SUMMARY_CASES: SummaryCase[] = [
  {
    name: 'boş liste',
    rows: [],
    expected: makeSummary({ testCount: 0 }),
  },
  {
    name: 'tek sonuç',
    rows: [{ correct: 15, wrong: 4, blank: 1, takenAt: '2026-11-19T09:00:00.000Z' }],
    expected: makeSummary({
      testCount: 1,
      totalQuestions: 20,
      correct: 15,
      wrong: 4,
      blank: 1,
      net: 14,
      accuracy: 0.75,
      netRatio: 0.7,
      lastTakenAt: '2026-11-19T09:00:00.000Z',
    }),
  },
  {
    name: 'birden çok sonuç, lastTakenAt en geç olan (sıra karışık)',
    rows: [
      { correct: 10, wrong: 2, blank: 0, takenAt: '2026-11-18T09:00:00.000Z' },
      { correct: 5, wrong: 5, blank: 2, takenAt: '2026-11-19T20:00:00.000Z' },
      { correct: 3, wrong: 1, blank: 4, takenAt: '2026-11-17T09:00:00.000Z' },
    ],
    expected: makeSummary({
      testCount: 3,
      totalQuestions: 32,
      correct: 18,
      wrong: 8,
      blank: 6,
      net: 16,
      accuracy: 18 / 32,
      netRatio: 16 / 32,
      lastTakenAt: '2026-11-19T20:00:00.000Z',
    }),
  },
  {
    name: 'yalnızca yanlış (negatif net ve netRatio −0.25)',
    rows: [{ correct: 0, wrong: 8, blank: 0, takenAt: '2026-11-19T09:00:00.000Z' }],
    expected: makeSummary({
      testCount: 1,
      totalQuestions: 8,
      wrong: 8,
      net: -2,
      accuracy: 0,
      netRatio: -0.25,
      lastTakenAt: '2026-11-19T09:00:00.000Z',
    }),
  },
  {
    name: 'yalnızca boş',
    rows: [{ correct: 0, wrong: 0, blank: 12, takenAt: '2026-11-19T09:00:00.000Z' }],
    expected: makeSummary({
      testCount: 1,
      totalQuestions: 12,
      blank: 12,
      lastTakenAt: '2026-11-19T09:00:00.000Z',
    }),
  },
  {
    name: 'sıfır sorulu test sayılır ama oranlar 0',
    rows: [{ correct: 0, wrong: 0, blank: 0, takenAt: '2026-11-19T09:00:00.000Z' }],
    expected: makeSummary({ testCount: 1, lastTakenAt: '2026-11-19T09:00:00.000Z' }),
  },
  {
    name: 'hepsi doğru',
    rows: [
      { correct: 10, wrong: 0, blank: 0, takenAt: '2026-11-19T09:00:00.000Z' },
      { correct: 30, wrong: 0, blank: 0, takenAt: '2026-11-19T08:00:00.000Z' },
    ],
    expected: makeSummary({
      testCount: 2,
      totalQuestions: 40,
      correct: 40,
      net: 40,
      accuracy: 1,
      netRatio: 1,
      lastTakenAt: '2026-11-19T09:00:00.000Z',
    }),
  },
]

function expectSummary(actual: TestSummary, expected: TestSummary): void {
  expect(actual.testCount).toBe(expected.testCount)
  expect(actual.totalQuestions).toBe(expected.totalQuestions)
  expect(actual.correct).toBe(expected.correct)
  expect(actual.wrong).toBe(expected.wrong)
  expect(actual.blank).toBe(expected.blank)
  expect(actual.net).toBe(expected.net)
  expect(actual.accuracy).toBeCloseTo(expected.accuracy, 10)
  expect(actual.netRatio).toBeCloseTo(expected.netRatio, 10)
  expect(actual.lastTakenAt).toBe(expected.lastTakenAt)
}

describe('summarizeResults', () => {
  it.each(SUMMARY_CASES)('$name', ({ rows, expected }) => {
    const results = rows.map((row) => makeResult(row))
    expectSummary(summarizeResults(results), expected)
  })

  it('girdiyi değiştirmez', () => {
    const results = deepFreeze([
      makeResult({ correct: 5, wrong: 1, takenAt: '2026-11-19T10:00:00.000Z' }),
      makeResult({ correct: 2, wrong: 3, takenAt: '2026-11-18T10:00:00.000Z' }),
    ])
    const snapshot = structuredClone(results)
    summarizeResults(results)
    expect(results).toEqual(snapshot)
  })
})

// ---------------------------------------------------------------------------
// summarizeBySubject / summarizeByTopic
// ---------------------------------------------------------------------------

type GroupRow = Pick<TestResult, 'subjectId' | 'topicId' | 'correct' | 'wrong' | 'blank'>

interface GroupExpectation {
  key: UUID
  testCount: number
  totalQuestions: number
  net: number
}

interface GroupCase {
  name: string
  rows: GroupRow[]
  bySubject: GroupExpectation[]
  byTopic: GroupExpectation[]
}

const GROUP_CASES: GroupCase[] = [
  { name: 'boş liste', rows: [], bySubject: [], byTopic: [] },
  {
    name: 'tek sonuç',
    rows: [{ subjectId: SUBJECT_A, topicId: TOPIC_1, correct: 8, wrong: 4, blank: 0 }],
    bySubject: [{ key: SUBJECT_A, testCount: 1, totalQuestions: 12, net: 7 }],
    byTopic: [{ key: TOPIC_1, testCount: 1, totalQuestions: 12, net: 7 }],
  },
  {
    name: 'iki ders, üç konu',
    rows: [
      { subjectId: SUBJECT_A, topicId: TOPIC_1, correct: 10, wrong: 2, blank: 0 },
      { subjectId: SUBJECT_A, topicId: TOPIC_2, correct: 5, wrong: 4, blank: 1 },
      { subjectId: SUBJECT_A, topicId: TOPIC_1, correct: 6, wrong: 0, blank: 2 },
      { subjectId: SUBJECT_B, topicId: TOPIC_3, correct: 0, wrong: 4, blank: 0 },
    ],
    bySubject: [
      { key: SUBJECT_A, testCount: 3, totalQuestions: 30, net: 19.5 },
      { key: SUBJECT_B, testCount: 1, totalQuestions: 4, net: -1 },
    ],
    byTopic: [
      { key: TOPIC_1, testCount: 2, totalQuestions: 20, net: 15.5 },
      { key: TOPIC_2, testCount: 1, totalQuestions: 10, net: 4 },
      { key: TOPIC_3, testCount: 1, totalQuestions: 4, net: -1 },
    ],
  },
  {
    name: 'topicId null olanlar konu özetinde atlanır, ders özetinde sayılır',
    rows: [
      { subjectId: SUBJECT_A, topicId: null, correct: 20, wrong: 0, blank: 0 },
      { subjectId: SUBJECT_A, topicId: TOPIC_1, correct: 4, wrong: 4, blank: 0 },
    ],
    bySubject: [{ key: SUBJECT_A, testCount: 2, totalQuestions: 28, net: 23 }],
    byTopic: [{ key: TOPIC_1, testCount: 1, totalQuestions: 8, net: 3 }],
  },
  {
    name: 'yalnızca topicId null',
    rows: [{ subjectId: SUBJECT_B, topicId: null, correct: 3, wrong: 0, blank: 0 }],
    bySubject: [{ key: SUBJECT_B, testCount: 1, totalQuestions: 3, net: 3 }],
    byTopic: [],
  },
]

function expectGroups(actual: Map<UUID, TestSummary>, expected: GroupExpectation[]): void {
  expect([...actual.keys()].sort()).toEqual(expected.map((e) => e.key).sort())
  for (const e of expected) {
    const summary = actual.get(e.key)
    expect(summary?.testCount).toBe(e.testCount)
    expect(summary?.totalQuestions).toBe(e.totalQuestions)
    expect(summary?.net).toBe(e.net)
  }
}

describe('summarizeBySubject', () => {
  it.each(GROUP_CASES)('$name', ({ rows, bySubject }) => {
    expectGroups(summarizeBySubject(rows.map((row) => makeResult(row))), bySubject)
  })
})

describe('summarizeByTopic', () => {
  it.each(GROUP_CASES)('$name', ({ rows, byTopic }) => {
    expectGroups(summarizeByTopic(rows.map((row) => makeResult(row))), byTopic)
  })
})

describe('gruplama girdiyi değiştirmez', () => {
  it.each([
    ['summarizeBySubject', summarizeBySubject],
    ['summarizeByTopic', summarizeByTopic],
  ] as const)('%s', (_name, fn) => {
    const results = deepFreeze([
      makeResult({ subjectId: SUBJECT_B, topicId: TOPIC_2, correct: 3 }),
      makeResult({ subjectId: SUBJECT_A, topicId: null, correct: 1 }),
    ])
    const snapshot = structuredClone(results)
    fn(results)
    expect(results).toEqual(snapshot)
  })
})

// ---------------------------------------------------------------------------
// findWeakestTopics
// ---------------------------------------------------------------------------

interface WeakInput {
  topicId: UUID
  totalQuestions: number
  netRatio: number
}

interface WeakCase {
  name: string
  topics: WeakInput[]
  options?: { minQuestions?: number; limit?: number }
  expected: UUID[]
}

const T = (n: number): UUID => `dddddddd-0000-4000-8000-${String(n).padStart(12, '0')}`

const WEAK_CASES: WeakCase[] = [
  { name: 'boş harita', topics: [], expected: [] },
  {
    name: 'netRatio artan sıralı',
    topics: [
      { topicId: T(1), totalQuestions: 40, netRatio: 0.8 },
      { topicId: T(2), totalQuestions: 40, netRatio: 0.1 },
      { topicId: T(3), totalQuestions: 40, netRatio: -0.2 },
      { topicId: T(4), totalQuestions: 40, netRatio: 0.5 },
    ],
    expected: [T(3), T(2), T(4), T(1)],
  },
  {
    name: 'varsayılan eşiğin altındaki konu dışarıda (19 soru)',
    topics: [
      { topicId: T(1), totalQuestions: 19, netRatio: -0.25 },
      { topicId: T(2), totalQuestions: 25, netRatio: 0.4 },
    ],
    expected: [T(2)],
  },
  {
    name: 'eşik tam sınırda (20 soru) dahil',
    topics: [
      { topicId: T(1), totalQuestions: 20, netRatio: 0.1 },
      { topicId: T(2), totalQuestions: 50, netRatio: 0.3 },
    ],
    expected: [T(1), T(2)],
  },
  {
    name: 'özel eşik (minQuestions 5)',
    topics: [
      { topicId: T(1), totalQuestions: 4, netRatio: 0 },
      { topicId: T(2), totalQuestions: 5, netRatio: 0.5 },
      { topicId: T(3), totalQuestions: 10, netRatio: 0.2 },
    ],
    options: { minQuestions: 5 },
    expected: [T(3), T(2)],
  },
  {
    name: 'eşitlikte çok soru çözülen önce',
    topics: [
      { topicId: T(1), totalQuestions: 30, netRatio: 0.5 },
      { topicId: T(2), totalQuestions: 80, netRatio: 0.5 },
      { topicId: T(3), totalQuestions: 50, netRatio: 0.5 },
    ],
    expected: [T(2), T(3), T(1)],
  },
  {
    name: 'netRatio ve soru eşitse topicId artan',
    topics: [
      { topicId: T(3), totalQuestions: 40, netRatio: 0.25 },
      { topicId: T(1), totalQuestions: 40, netRatio: 0.25 },
      { topicId: T(2), totalQuestions: 40, netRatio: 0.25 },
    ],
    expected: [T(1), T(2), T(3)],
  },
  {
    name: 'varsayılan limit 5',
    topics: [1, 2, 3, 4, 5, 6, 7].map((n) => ({
      topicId: T(n),
      totalQuestions: 20,
      netRatio: n / 10,
    })),
    expected: [T(1), T(2), T(3), T(4), T(5)],
  },
  {
    name: 'özel limit 2',
    topics: [
      { topicId: T(1), totalQuestions: 20, netRatio: 0.9 },
      { topicId: T(2), totalQuestions: 20, netRatio: 0.3 },
      { topicId: T(3), totalQuestions: 20, netRatio: 0.6 },
    ],
    options: { limit: 2 },
    expected: [T(2), T(3)],
  },
  {
    name: 'limit 0 → boş',
    topics: [{ topicId: T(1), totalQuestions: 20, netRatio: 0.1 }],
    options: { limit: 0 },
    expected: [],
  },
  {
    name: 'limit konu sayısından büyük',
    topics: [
      { topicId: T(2), totalQuestions: 20, netRatio: 0.2 },
      { topicId: T(1), totalQuestions: 20, netRatio: 0.1 },
    ],
    options: { limit: 10 },
    expected: [T(1), T(2)],
  },
  {
    name: 'hiçbiri eşiği geçmiyor',
    topics: [
      { topicId: T(1), totalQuestions: 0, netRatio: 0 },
      { topicId: T(2), totalQuestions: 10, netRatio: -0.1 },
    ],
    expected: [],
  },
]

function toSummaryMap(topics: WeakInput[]): Map<UUID, TestSummary> {
  return new Map(
    topics.map((t) => [
      t.topicId,
      makeSummary({ totalQuestions: t.totalQuestions, netRatio: t.netRatio }),
    ]),
  )
}

describe('findWeakestTopics', () => {
  it.each(WEAK_CASES)('$name', ({ topics, options, expected }) => {
    const summaries = toSummaryMap(topics)
    const weakest = findWeakestTopics(summaries, options)
    expect(weakest.map((w) => w.topicId)).toEqual(expected)
    for (const w of weakest) expect(w.summary).toBe(summaries.get(w.topicId))
  })

  it('girdi haritasını değiştirmez', () => {
    const summaries = toSummaryMap([
      { topicId: T(2), totalQuestions: 30, netRatio: 0.5 },
      { topicId: T(1), totalQuestions: 30, netRatio: 0.1 },
    ])
    const keysBefore = [...summaries.keys()]
    findWeakestTopics(summaries)
    expect([...summaries.keys()]).toEqual(keysBefore)
    expect(summaries.size).toBe(2)
  })
})

// ---------------------------------------------------------------------------
// dailyNetTrend
// ---------------------------------------------------------------------------

interface TrendRow {
  takenAt: string
  correct: number
  wrong: number
}

interface TrendPointExpectation {
  date: string
  testCount: number
  net: number
}

interface TrendCase {
  name: string
  rows: TrendRow[]
  expected: TrendPointExpectation[]
}

const TREND_CASES: TrendCase[] = [
  { name: 'boş liste', rows: [], expected: [] },
  {
    name: 'tek sonuç',
    rows: [{ takenAt: localISO(2026, 10, 19, 10), correct: 10, wrong: 2 }],
    expected: [{ date: '2026-11-19', testCount: 1, net: 9.5 }],
  },
  {
    name: 'aynı gün birden çok test toplanır',
    rows: [
      { takenAt: localISO(2026, 10, 19, 8), correct: 10, wrong: 4 },
      { takenAt: localISO(2026, 10, 19, 21), correct: 5, wrong: 1 },
    ],
    expected: [{ date: '2026-11-19', testCount: 2, net: 13.75 }],
  },
  {
    name: 'gün sırasına göre artan (girdi karışık)',
    rows: [
      { takenAt: localISO(2026, 10, 20, 9), correct: 3, wrong: 0 },
      { takenAt: localISO(2026, 10, 17, 9), correct: 1, wrong: 0 },
      { takenAt: localISO(2026, 10, 19, 9), correct: 2, wrong: 0 },
    ],
    expected: [
      { date: '2026-11-17', testCount: 1, net: 1 },
      { date: '2026-11-19', testCount: 1, net: 2 },
      { date: '2026-11-20', testCount: 1, net: 3 },
    ],
  },
  {
    name: 'gece yarısı sınırı: 23:59 ve 00:00 farklı günler',
    rows: [
      { takenAt: localISO(2026, 10, 19, 23, 59), correct: 4, wrong: 0 },
      { takenAt: localISO(2026, 10, 20, 0, 0), correct: 6, wrong: 4 },
    ],
    expected: [
      { date: '2026-11-19', testCount: 1, net: 4 },
      { date: '2026-11-20', testCount: 1, net: 5 },
    ],
  },
  {
    name: 'ay ve yıl geçişi',
    rows: [
      { takenAt: localISO(2027, 0, 1, 0, 30), correct: 2, wrong: 0 },
      { takenAt: localISO(2026, 11, 31, 23, 30), correct: 1, wrong: 0 },
    ],
    expected: [
      { date: '2026-12-31', testCount: 1, net: 1 },
      { date: '2027-01-01', testCount: 1, net: 2 },
    ],
  },
  {
    name: 'negatif günlük net',
    rows: [{ takenAt: localISO(2026, 10, 19, 12), correct: 0, wrong: 12 }],
    expected: [{ date: '2026-11-19', testCount: 1, net: -3 }],
  },
]

describe('dailyNetTrend', () => {
  it.each(TREND_CASES)('$name', ({ rows, expected }) => {
    const trend = dailyNetTrend(rows.map((row) => makeResult(row)))
    expect(
      trend.map((p) => ({ date: p.date, testCount: p.summary.testCount, net: p.summary.net })),
    ).toEqual(expected)
  })

  it('her noktanın özeti o günün summarizeResults sonucudur', () => {
    const morning = makeResult({
      takenAt: localISO(2026, 10, 19, 8),
      correct: 7,
      wrong: 2,
      blank: 1,
    })
    const evening = makeResult({
      takenAt: localISO(2026, 10, 19, 22),
      correct: 3,
      wrong: 1,
      blank: 6,
    })
    const [point] = dailyNetTrend([evening, morning])
    expect(point?.summary).toEqual(summarizeResults([morning, evening]))
  })

  it('girdiyi değiştirmez', () => {
    const results = deepFreeze([
      makeResult({ takenAt: localISO(2026, 10, 20, 9), correct: 3 }),
      makeResult({ takenAt: localISO(2026, 10, 18, 9), correct: 1 }),
    ])
    const snapshot = structuredClone(results)
    dailyNetTrend(results)
    expect(results).toEqual(snapshot)
  })
})
