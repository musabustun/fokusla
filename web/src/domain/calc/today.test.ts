/**
 * Bugün hesapları testleri. Vakalar tablo tabanlıdır ve düz veriyle kurulur — Swift XCTest
 * port'unda aynen tekrar kullanılacak. Anlar YEREL saatle (`new Date(y, m, d, h, min)`) üretilir;
 * böylece testler hangi saat diliminde koşarsa koşsun yerel gün/saat sabittir.
 */
import { describe, expect, it } from 'vitest'
import type {
  Book,
  FocusSegment,
  FocusSegmentKind,
  FocusSession,
  ISODate,
  SocialPresence,
  Task,
  TaskCompletion,
  TestResult,
} from '../types'
import type { BookStatus, BookSummary } from './books'
import { MIN_QUESTIONS_FOR_WEAKNESS, summarizeResults } from './tests'
import {
  RECENT_TESTS_WINDOW_DAYS,
  TODAY_BOOK_LIMIT,
  TODAY_CHART_DAYS,
  TODAY_WEAK_TOPIC_LIMIT,
  activeFocusState,
  booksInProgress,
  focusingFriends,
  greetingKey,
  planTaskToggle,
  recentFocusTotals,
  recentTestsSummary,
  todayFocusSummary,
  todayTaskOverview,
  weakestTopicsForToday,
  type ActiveFocusState,
  type GreetingKey,
  type TaskToggleAction,
  type TodayFocusSummary,
  type TodayTaskGroup,
} from './today'

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

const SECOND = 1000
const MIN = 60 * SECOND

/** Referans gün: 2026-11-19 Perşembe, "şimdi" 10:00 (yerel). */
const TODAY: ISODate = '2026-11-19'
const NOW = new Date(2026, 10, 19, 10, 0)
const FIXED = '2026-01-01T00:00:00.000Z'
const DELETED_AT = '2026-11-19T12:00:00.000Z'

/** Kasım 2026'nın `day` gününde YEREL saatle bir an (ISODateTime). */
function local(day: number, hour = 12, minute = 0, second = 0): string {
  return new Date(2026, 10, day, hour, minute, second).toISOString()
}

let seq = 0
const nextId = (prefix: string) => {
  seq += 1
  return `${prefix}-${seq}`
}

interface SessionSpec {
  id: string
  startedAt: string
  endedAt?: string | null
  deletedAt?: string | null
}

function session(spec: SessionSpec): FocusSession {
  return {
    id: spec.id,
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: spec.deletedAt ?? null,
    subjectId: null,
    topicId: null,
    startedAt: spec.startedAt,
    endedAt: spec.endedAt ?? null,
    note: null,
  }
}

interface SegmentSpec {
  sessionId: string
  startedAt: string
  endedAt: string | null
  kind?: FocusSegmentKind
  deletedAt?: string | null
}

function seg(spec: SegmentSpec): FocusSegment {
  return {
    id: nextId('segment'),
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: spec.deletedAt ?? null,
    sessionId: spec.sessionId,
    kind: spec.kind ?? 'focus',
    startedAt: spec.startedAt,
    endedAt: spec.endedAt,
  }
}

function makeTask(overrides: Partial<Task> = {}): Task {
  return {
    id: nextId('task'),
    createdAt: local(1),
    updatedAt: local(1),
    deletedAt: null,
    title: 'Görev',
    kind: 'routine',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: { frequency: 'daily', weekdays: [] },
    completedAt: null,
    order: 0,
    ...overrides,
  }
}

function makeAssignment(overrides: Partial<Task> = {}): Task {
  return makeTask({ kind: 'assignment', recurrence: null, ...overrides })
}

function makeCompletion(overrides: Partial<TaskCompletion> = {}): TaskCompletion {
  return {
    id: nextId('completion'),
    createdAt: local(19, 9),
    updatedAt: local(19, 9),
    deletedAt: null,
    taskId: 'routine',
    date: TODAY,
    completedAt: local(19, 9),
    ...overrides,
  }
}

interface ResultSpec {
  takenAt: string
  correct: number
  wrong: number
  blank: number
  topicId?: string | null
  deletedAt?: string | null
  id?: string
}

function result(spec: ResultSpec): TestResult {
  return {
    id: spec.id ?? nextId('result'),
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: spec.deletedAt ?? null,
    subjectId: 'subject-1',
    topicId: spec.topicId ?? null,
    bookId: null,
    label: null,
    takenAt: spec.takenAt,
    correct: spec.correct,
    wrong: spec.wrong,
    blank: spec.blank,
    durationSeconds: null,
    note: null,
  }
}

function bookSummary(id: string, status: BookStatus): BookSummary {
  const book: Book = {
    id,
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: null,
    title: id,
    publisher: null,
    kind: 'questionBank',
    subjectId: null,
    exam: null,
    unit: 'page',
    totalUnits: 100,
    archivedAt: null,
  }
  return {
    book,
    latest: undefined,
    reachedUnit: 0,
    ratio: 0,
    status,
    lastProgressAt: null,
    weeklyPace: null,
    daysToFinish: null,
    activityAt: FIXED,
  }
}

// ---------------------------------------------------------------------------
// Sabitler
// ---------------------------------------------------------------------------

describe('sabitler', () => {
  it('belgelenen değerleri taşır', () => {
    expect(TODAY_CHART_DAYS).toBe(7)
    expect(RECENT_TESTS_WINDOW_DAYS).toBe(7)
    expect(TODAY_WEAK_TOPIC_LIMIT).toBe(3)
    expect(TODAY_BOOK_LIMIT).toBe(3)
  })
})

// ---------------------------------------------------------------------------
// greetingKey
// ---------------------------------------------------------------------------

describe('greetingKey', () => {
  it.each<{ name: string; hour: number; minute: number; expected: GreetingKey }>([
    { name: '00:00 gece', hour: 0, minute: 0, expected: 'night' },
    { name: '04:00 gece', hour: 4, minute: 0, expected: 'night' },
    { name: '04:59 gece', hour: 4, minute: 59, expected: 'night' },
    { name: '05:00 sabah (sınır)', hour: 5, minute: 0, expected: 'morning' },
    { name: '11:00 sabah', hour: 11, minute: 0, expected: 'morning' },
    { name: '11:59 sabah', hour: 11, minute: 59, expected: 'morning' },
    { name: '12:00 öğleden sonra (sınır)', hour: 12, minute: 0, expected: 'afternoon' },
    { name: '17:00 öğleden sonra', hour: 17, minute: 0, expected: 'afternoon' },
    { name: '17:59 öğleden sonra', hour: 17, minute: 59, expected: 'afternoon' },
    { name: '18:00 akşam (sınır)', hour: 18, minute: 0, expected: 'evening' },
    { name: '21:00 akşam', hour: 21, minute: 0, expected: 'evening' },
    { name: '21:59 akşam', hour: 21, minute: 59, expected: 'evening' },
    { name: '22:00 gece (sınır)', hour: 22, minute: 0, expected: 'night' },
    { name: '23:00 gece', hour: 23, minute: 0, expected: 'night' },
  ])('$name', ({ hour, minute, expected }) => {
    expect(greetingKey(new Date(2026, 10, 19, hour, minute))).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// todayFocusSummary
// ---------------------------------------------------------------------------

describe('todayFocusSummary', () => {
  it.each<{
    name: string
    sessions: FocusSession[]
    segments: FocusSegment[]
    expected: TodayFocusSummary
  }>([
    {
      name: 'veri yok → hepsi 0',
      sessions: [],
      segments: [],
      expected: { totalMs: 0, sessionCount: 0, averageFocusMs: 0 },
    },
    {
      name: 'açık oturum: kapanmış + açık odak; ortalama yalnızca kapanmışlar, mola sayılmaz',
      sessions: [session({ id: 'open', startedAt: local(19, 8) })],
      segments: [
        seg({ sessionId: 'open', startedAt: local(19, 8), endedAt: local(19, 8, 30) }),
        seg({
          sessionId: 'open',
          kind: 'break',
          startedAt: local(19, 8, 30),
          endedAt: local(19, 8, 40),
        }),
        seg({ sessionId: 'open', startedAt: local(19, 8, 40), endedAt: local(19, 9) }),
        seg({ sessionId: 'open', startedAt: local(19, 9, 40), endedAt: null }),
      ],
      expected: { totalMs: 70 * MIN, sessionCount: 1, averageFocusMs: 25 * MIN },
    },
    {
      name: 'dün başlayıp gece yarısını aşan oturum: yalnızca bugünkü kısım toplanır',
      sessions: [session({ id: 'cross', startedAt: local(18, 23, 30), endedAt: local(19, 0, 30) })],
      segments: [
        seg({ sessionId: 'cross', startedAt: local(18, 23, 30), endedAt: local(19, 0, 20) }),
      ],
      expected: { totalMs: 20 * MIN, sessionCount: 1, averageFocusMs: 50 * MIN },
    },
    {
      name: 'dün başlayıp gece yarısından sonra biten ama bugün yalnızca molası olan oturum sayılmaz',
      sessions: [
        session({ id: 'cross-break', startedAt: local(18, 23), endedAt: local(19, 0, 15) }),
      ],
      segments: [
        seg({ sessionId: 'cross-break', startedAt: local(18, 23), endedAt: local(18, 23, 50) }),
        seg({
          sessionId: 'cross-break',
          kind: 'break',
          startedAt: local(18, 23, 50),
          endedAt: local(19, 0, 15),
        }),
      ],
      expected: { totalMs: 0, sessionCount: 0, averageFocusMs: 0 },
    },
    {
      name: 'silinmiş oturum ve silinmiş segment yok sayılır',
      sessions: [
        session({ id: 'live', startedAt: local(19, 8), endedAt: local(19, 9) }),
        session({ id: 'gone', startedAt: local(19, 9), deletedAt: DELETED_AT }),
      ],
      segments: [
        seg({ sessionId: 'live', startedAt: local(19, 8), endedAt: local(19, 8, 30) }),
        seg({
          sessionId: 'live',
          startedAt: local(19, 8, 30),
          endedAt: local(19, 9),
          deletedAt: DELETED_AT,
        }),
        seg({ sessionId: 'gone', startedAt: local(19, 9), endedAt: local(19, 9, 50) }),
      ],
      expected: { totalMs: 30 * MIN, sessionCount: 1, averageFocusMs: 30 * MIN },
    },
    {
      name: 'önceki günün oturumu sayıma ve ortalamaya girmez',
      sessions: [
        session({ id: 'old', startedAt: local(17, 9), endedAt: local(17, 10) }),
        session({ id: 'today', startedAt: local(19, 8), endedAt: local(19, 8, 20) }),
      ],
      segments: [
        seg({ sessionId: 'old', startedAt: local(17, 9), endedAt: local(17, 10) }),
        seg({ sessionId: 'today', startedAt: local(19, 8), endedAt: local(19, 8, 20) }),
      ],
      expected: { totalMs: 20 * MIN, sessionCount: 1, averageFocusMs: 20 * MIN },
    },
    {
      name: 'bugün başlayıp segmentsiz biten oturum sayılır (süre 0)',
      sessions: [session({ id: 'empty', startedAt: local(19, 7), endedAt: local(19, 7, 1) })],
      segments: [],
      expected: { totalMs: 0, sessionCount: 1, averageFocusMs: 0 },
    },
  ])('$name', ({ sessions, segments, expected }) => {
    expect(todayFocusSummary(sessions, segments, TODAY, NOW)).toEqual(expected)
  })
})

// ---------------------------------------------------------------------------
// activeFocusState
// ---------------------------------------------------------------------------

describe('activeFocusState', () => {
  const otherSessionOpen = seg({ sessionId: 'other', startedAt: local(19, 7), endedAt: null })

  it.each<{
    name: string
    session: FocusSession | undefined
    segments: FocusSegment[]
    expected: ActiveFocusState | null
  }>([
    { name: 'oturum yok → null', session: undefined, segments: [], expected: null },
    {
      name: 'bitmiş oturum → null',
      session: session({ id: 'a', startedAt: local(19, 8), endedAt: local(19, 9) }),
      segments: [seg({ sessionId: 'a', startedAt: local(19, 8), endedAt: local(19, 9) })],
      expected: null,
    },
    {
      name: 'silinmiş oturum → null',
      session: session({ id: 'a', startedAt: local(19, 9), deletedAt: DELETED_AT }),
      segments: [seg({ sessionId: 'a', startedAt: local(19, 9), endedAt: null })],
      expected: null,
    },
    {
      name: 'odak evresi: açık odak segmenti now’a kadar; başka oturumun segmenti sayılmaz',
      session: session({ id: 'a', startedAt: local(19, 9) }),
      segments: [
        otherSessionOpen,
        seg({ sessionId: 'a', startedAt: local(19, 9), endedAt: local(19, 9, 30) }),
        seg({
          sessionId: 'a',
          kind: 'break',
          startedAt: local(19, 9, 30),
          endedAt: local(19, 9, 40),
        }),
        seg({ sessionId: 'a', startedAt: local(19, 9, 40), endedAt: null }),
      ],
      expected: { phase: 'focus', sessionFocusMs: 50 * MIN },
    },
    {
      name: 'mola evresi: açık mola odak süresine eklenmez',
      session: session({ id: 'a', startedAt: local(19, 9) }),
      segments: [
        otherSessionOpen,
        seg({ sessionId: 'a', startedAt: local(19, 9), endedAt: local(19, 9, 45) }),
        seg({ sessionId: 'a', kind: 'break', startedAt: local(19, 9, 45), endedAt: null }),
      ],
      expected: { phase: 'break', sessionFocusMs: 45 * MIN },
    },
    {
      name: 'açık oturumda yalnızca başka oturumun açık odağı var → mola, 0',
      session: session({ id: 'a', startedAt: local(19, 9) }),
      segments: [otherSessionOpen],
      expected: { phase: 'break', sessionFocusMs: 0 },
    },
  ])('$name', ({ session: s, segments, expected }) => {
    expect(activeFocusState(s, segments, NOW)).toEqual(expected)
  })
})

// ---------------------------------------------------------------------------
// recentFocusTotals
// ---------------------------------------------------------------------------

describe('recentFocusTotals', () => {
  const sessions = [
    session({ id: 'past', startedAt: local(17, 9), endedAt: local(17, 10) }),
    session({ id: 'now', startedAt: local(19, 9, 30) }),
  ]
  const segments = [
    seg({ sessionId: 'past', startedAt: local(17, 9), endedAt: local(17, 9, 30) }),
    seg({ sessionId: 'now', startedAt: local(19, 9, 30), endedAt: null }),
  ]

  it('varsayılan 7 gün, eskiden yeniye (son eleman bugün), açık segment now’a kadar', () => {
    expect(recentFocusTotals(sessions, segments, TODAY, NOW)).toEqual([
      { day: '2026-11-13', focusMs: 0 },
      { day: '2026-11-14', focusMs: 0 },
      { day: '2026-11-15', focusMs: 0 },
      { day: '2026-11-16', focusMs: 0 },
      { day: '2026-11-17', focusMs: 30 * MIN },
      { day: '2026-11-18', focusMs: 0 },
      { day: '2026-11-19', focusMs: 30 * MIN },
    ])
  })

  it.each<{ name: string; today: ISODate; days: number; expected: ISODate[] }>([
    { name: 'days = 0 → boş', today: TODAY, days: 0, expected: [] },
    { name: 'days < 0 → boş', today: TODAY, days: -3, expected: [] },
    { name: 'days = 1 → yalnızca bugün', today: TODAY, days: 1, expected: [TODAY] },
    {
      name: 'kesirli days aşağı yuvarlanır (2.9 → 2)',
      today: TODAY,
      days: 2.9,
      expected: ['2026-11-18', '2026-11-19'],
    },
    {
      name: 'ay sınırı (artık olmayan yıl şubatı)',
      today: '2026-03-01',
      days: 3,
      expected: ['2026-02-27', '2026-02-28', '2026-03-01'],
    },
  ])('$name', ({ today, days, expected }) => {
    expect(recentFocusTotals([], [], today, NOW, days).map((d) => d.day)).toEqual(expected)
  })
})

// ---------------------------------------------------------------------------
// todayTaskOverview
// ---------------------------------------------------------------------------

describe('todayTaskOverview', () => {
  it('boş → öğe yok, sayılar 0', () => {
    expect(todayTaskOverview([], [], TODAY)).toEqual({ items: [], totalCount: 0, doneCount: 0 })
  })

  it('gruplar sırayla: geciken, rutin, bugün, yaklaşan; yaklaşanlar sayılmaz; silinenler yok', () => {
    const routineB = makeTask({ title: 'Rutin B', order: 1 })
    const routineA = makeTask({ title: 'Rutin A', order: 0 })
    const tasks = [
      makeAssignment({
        title: 'Yaklaşan (bugün bitti)',
        dueDate: '2026-11-22',
        completedAt: local(19, 9),
      }),
      makeAssignment({ title: 'Tarihsiz' }),
      routineB,
      makeAssignment({ title: 'Bugün teslim (bitti)', dueDate: TODAY, completedAt: local(19, 8) }),
      makeAssignment({ title: 'Geciken', dueDate: '2026-11-17' }),
      routineA,
      makeAssignment({ title: 'Silinmiş ödev', dueDate: TODAY, deletedAt: DELETED_AT }),
      makeTask({ title: 'Silinmiş rutin', deletedAt: DELETED_AT }),
      makeAssignment({ title: 'Ufkun ötesi', dueDate: '2026-12-31' }),
    ]
    const completions = [
      makeCompletion({ taskId: routineA.id }),
      makeCompletion({ taskId: routineB.id, date: '2026-11-18' }),
      makeCompletion({ taskId: routineB.id, deletedAt: DELETED_AT }),
    ]

    const overview = todayTaskOverview(tasks, completions, TODAY)

    expect(
      overview.items.map((i) => ({ title: i.task.title, group: i.group, done: i.done })),
    ).toEqual<{ title: string; group: TodayTaskGroup; done: boolean }[]>([
      { title: 'Geciken', group: 'overdue', done: false },
      { title: 'Rutin A', group: 'routine', done: true },
      { title: 'Rutin B', group: 'routine', done: false },
      { title: 'Bugün teslim (bitti)', group: 'dueToday', done: true },
      { title: 'Tarihsiz', group: 'dueToday', done: false },
      { title: 'Yaklaşan (bugün bitti)', group: 'upcoming', done: true },
    ])
    expect(overview.totalCount).toBe(5)
    expect(overview.doneCount).toBe(2)
  })
})

// ---------------------------------------------------------------------------
// planTaskToggle
// ---------------------------------------------------------------------------

describe('planTaskToggle', () => {
  const routine = makeTask({ id: 'routine' })
  const comp = (id: string, overrides: Partial<TaskCompletion> = {}) =>
    makeCompletion({ id, taskId: 'routine', ...overrides })

  it.each<{
    name: string
    task: Task
    completions: TaskCompletion[]
    expected: TaskToggleAction
  }>([
    {
      name: 'silinmiş görev → yazma yok',
      task: makeTask({ id: 'routine', deletedAt: DELETED_AT }),
      completions: [comp('c1')],
      expected: { kind: 'none' },
    },
    {
      name: 'silinmiş ödev → yazma yok',
      task: makeAssignment({ deletedAt: DELETED_AT }),
      completions: [],
      expected: { kind: 'none' },
    },
    {
      name: 'açık ödev → tamamlandı yap',
      task: makeAssignment({ id: 'a1' }),
      completions: [],
      expected: { kind: 'setAssignmentCompleted', taskId: 'a1', completed: true },
    },
    {
      name: 'tamamlanmış ödev → geri al',
      task: makeAssignment({ id: 'a1', completedAt: local(18, 9) }),
      completions: [],
      expected: { kind: 'setAssignmentCompleted', taskId: 'a1', completed: false },
    },
    {
      name: 'tamamlaması olmayan rutin → tamamlama oluştur',
      task: routine,
      completions: [],
      expected: { kind: 'createCompletion', taskId: 'routine', date: TODAY },
    },
    {
      name: 'rutinin yalnızca silinmiş / başka gün / başka görev tamamlaması var → oluştur',
      task: routine,
      completions: [
        comp('deleted', { deletedAt: DELETED_AT }),
        comp('yesterday', { date: '2026-11-18' }),
        makeCompletion({ id: 'other-task', taskId: 'other' }),
      ],
      expected: { kind: 'createCompletion', taskId: 'routine', date: TODAY },
    },
    {
      name: 'tekrarlı tamamlamalar → o günün TÜM silinmemişleri silinir (başka gün/görev hariç)',
      task: routine,
      completions: [
        comp('c1', { completedAt: local(19, 9) }),
        comp('yesterday', { date: '2026-11-18' }),
        comp('deleted', { deletedAt: DELETED_AT }),
        makeCompletion({ id: 'other-task', taskId: 'other' }),
        comp('c2', { completedAt: local(19, 8) }),
      ],
      expected: { kind: 'deleteCompletions', completionIds: ['c1', 'c2'] },
    },
  ])('$name', ({ task, completions, expected }) => {
    expect(planTaskToggle(task, completions, TODAY)).toEqual(expected)
  })
})

// ---------------------------------------------------------------------------
// recentTestsSummary
// ---------------------------------------------------------------------------

describe('recentTestsSummary', () => {
  const todayLate = result({
    id: 'today-late',
    takenAt: local(19, 23, 59),
    correct: 10,
    wrong: 2,
    blank: 3,
  })
  const todayEarly = result({
    id: 'today-early',
    takenAt: local(19, 0, 0),
    correct: 5,
    wrong: 0,
    blank: 0,
  })
  const yesterday = result({
    id: 'yesterday',
    takenAt: local(18, 12),
    correct: 3,
    wrong: 0,
    blank: 0,
  })
  const sixDaysAgo = result({ id: 'six', takenAt: local(13, 0, 0), correct: 4, wrong: 4, blank: 2 })
  const sevenDaysAgo = result({
    id: 'seven',
    takenAt: local(12, 23, 59),
    correct: 9,
    wrong: 9,
    blank: 9,
  })
  const tomorrow = result({
    id: 'future',
    takenAt: local(20, 0, 0),
    correct: 7,
    wrong: 7,
    blank: 7,
  })
  const deletedToday = result({
    id: 'deleted',
    takenAt: local(19, 9),
    correct: 50,
    wrong: 0,
    blank: 0,
    deletedAt: DELETED_AT,
  })
  const all = [todayLate, todayEarly, yesterday, sixDaysAgo, sevenDaysAgo, tomorrow, deletedToday]

  it('varsayılan 7 günlük pencere: 6 gün önce dahil, 7 gün önce / gelecek / silinmiş hariç', () => {
    const summary = recentTestsSummary(all, TODAY)
    expect(summary.todayQuestions).toBe(20)
    expect(summary.window).toEqual(summarizeResults([todayLate, todayEarly, yesterday, sixDaysAgo]))
    expect(summary.window).toMatchObject({
      testCount: 4,
      totalQuestions: 33,
      correct: 22,
      wrong: 6,
      blank: 5,
      net: 20.5,
      lastTakenAt: todayLate.takenAt,
    })
    expect(summary.allTimeCount).toBe(6)
  })

  it.each<{ name: string; windowDays: number; expectedIds: string[] }>([
    {
      name: '7 gün',
      windowDays: 7,
      expectedIds: ['today-late', 'today-early', 'yesterday', 'six'],
    },
    {
      name: '8 gün → 7 gün önce de dahil',
      windowDays: 8,
      expectedIds: ['today-late', 'today-early', 'yesterday', 'six', 'seven'],
    },
    {
      name: '2.5 gün → 2 (bugün + dün)',
      windowDays: 2.5,
      expectedIds: ['today-late', 'today-early', 'yesterday'],
    },
    { name: '1 gün → yalnızca bugün', windowDays: 1, expectedIds: ['today-late', 'today-early'] },
    { name: '0 gün → 1 sayılır', windowDays: 0, expectedIds: ['today-late', 'today-early'] },
    { name: 'negatif → 1 sayılır', windowDays: -5, expectedIds: ['today-late', 'today-early'] },
  ])('pencere: $name', ({ windowDays, expectedIds }) => {
    const byId = new Map(all.map((r) => [r.id, r]))
    const expected = summarizeResults(expectedIds.map((id) => byId.get(id) as TestResult))
    const summary = recentTestsSummary(all, TODAY, windowDays)
    expect(summary.window).toEqual(expected)
    expect(summary.todayQuestions).toBe(20)
    expect(summary.allTimeCount).toBe(6)
  })

  it('boş → sıfırlar, lastTakenAt null', () => {
    expect(recentTestsSummary([], TODAY)).toEqual({
      todayQuestions: 0,
      window: summarizeResults([]),
      allTimeCount: 0,
    })
  })

  it('yalnızca silinmiş sonuçlar → allTimeCount 0', () => {
    expect(recentTestsSummary([deletedToday], TODAY).allTimeCount).toBe(0)
  })
})

// ---------------------------------------------------------------------------
// weakestTopicsForToday
// ---------------------------------------------------------------------------

describe('weakestTopicsForToday', () => {
  const at = local(10)
  // Her konu 20 soru (eşik); netRatio: t1 −0.1, t2 0.125, t3 0.4, t4 0.7, t5 1.
  const results = [
    result({ topicId: 't5', takenAt: at, correct: 20, wrong: 0, blank: 0 }),
    result({ topicId: 't3', takenAt: at, correct: 10, wrong: 8, blank: 2 }),
    result({ topicId: 't1', takenAt: at, correct: 2, wrong: 16, blank: 2 }),
    result({ topicId: 't4', takenAt: at, correct: 15, wrong: 4, blank: 1 }),
    result({ topicId: 't2', takenAt: at, correct: 5, wrong: 10, blank: 5 }),
    // Eşiğin altında (19 soru) — çok kötü olsa da listeye girmez.
    result({ topicId: 'few', takenAt: at, correct: 0, wrong: 19, blank: 0 }),
    // Yalnızca silinmiş sonucu olan konu.
    result({
      topicId: 'gone',
      takenAt: at,
      correct: 0,
      wrong: 40,
      blank: 0,
      deletedAt: DELETED_AT,
    }),
    // Silinmiş sonuç sayılmazsa eşiğin altında kalır (10 + 10 silinmiş).
    result({ topicId: 'half', takenAt: at, correct: 0, wrong: 10, blank: 0 }),
    result({
      topicId: 'half',
      takenAt: at,
      correct: 0,
      wrong: 10,
      blank: 0,
      deletedAt: DELETED_AT,
    }),
    // Konusuz sonuç atlanır.
    result({ topicId: null, takenAt: at, correct: 0, wrong: 30, blank: 0 }),
  ]

  it('eşik tests calc ile aynı (20 soru)', () => {
    expect(MIN_QUESTIONS_FOR_WEAKNESS).toBe(20)
  })

  it.each<{ name: string; limit: number | undefined; expected: string[] }>([
    { name: 'varsayılan limit 3', limit: undefined, expected: ['t1', 't2', 't3'] },
    { name: 'limit 1', limit: 1, expected: ['t1'] },
    { name: 'limit 10 → eşiği geçen tümü', limit: 10, expected: ['t1', 't2', 't3', 't4', 't5'] },
    { name: 'limit 0 → boş', limit: 0, expected: [] },
  ])('$name', ({ limit, expected }) => {
    const weak =
      limit === undefined ? weakestTopicsForToday(results) : weakestTopicsForToday(results, limit)
    expect(weak.map((w) => w.topicId)).toEqual(expected)
  })

  it('özet tests calc summarizeResults ile aynı', () => {
    const [first] = weakestTopicsForToday(results, 1)
    expect(first?.summary).toEqual(summarizeResults(results.filter((r) => r.topicId === 't1')))
  })

  it('boş → boş', () => {
    expect(weakestTopicsForToday([])).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// booksInProgress
// ---------------------------------------------------------------------------

describe('booksInProgress', () => {
  const summaries = [
    bookSummary('completed', 'completed'),
    bookSummary('n1', 'notStarted'),
    bookSummary('p1', 'inProgress'),
    bookSummary('archived', 'archived'),
    bookSummary('p2', 'inProgress'),
    bookSummary('n2', 'notStarted'),
  ]

  it.each<{ name: string; limit: number | undefined; expected: string[] }>([
    {
      name: 'varsayılan limit 3: önce devam edenler, sonra başlanmamışlar',
      limit: undefined,
      expected: ['p1', 'p2', 'n1'],
    },
    {
      name: 'büyük limit: bitmiş/arşivlenmiş hariç tümü, girdi sırası korunur',
      limit: 10,
      expected: ['p1', 'p2', 'n1', 'n2'],
    },
    { name: 'limit 1', limit: 1, expected: ['p1'] },
    { name: 'limit 0 → boş', limit: 0, expected: [] },
    { name: 'limit negatif → boş', limit: -1, expected: [] },
  ])('$name', ({ limit, expected }) => {
    const list =
      limit === undefined ? booksInProgress(summaries) : booksInProgress(summaries, limit)
    expect(list.map((s) => s.book.id)).toEqual(expected)
  })

  it('boş → boş', () => {
    expect(booksInProgress([])).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// focusingFriends
// ---------------------------------------------------------------------------

describe('focusingFriends', () => {
  interface FriendLike {
    id: string
    username: string
    presence: SocialPresence | null
  }

  const presence = (state: SocialPresence['state'], updatedMsAgo: number): SocialPresence => ({
    state,
    sessionStartedAt: state === 'offline' ? null : local(19, 9),
    stateSince: state === 'offline' ? null : local(19, 9),
    todayFocusMs: 0,
    updatedAt: new Date(NOW.getTime() - updatedMsAgo).toISOString(),
  })
  const friend = (username: string, p: SocialPresence | null): FriendLike => ({
    id: `friend-${username}`,
    username,
    presence: p,
  })

  const friends: FriendLike[] = [
    friend('zeynep', presence('focusing', 1 * MIN)),
    friend('oya', presence('focusing', 2 * MIN)),
    friend('Çağla', presence('focusing', 10 * MIN)), // tam 10 dk: hâlâ geçerli
    friend('ali', presence('focusing', 10 * MIN + SECOND)), // bayat → çevrimdışı
    friend('mehmet', presence('onBreak', 1 * MIN)),
    friend('can', null),
    friend('ömer', presence('focusing', 0)),
    friend('ibrahim', presence('offline', 0)),
    friend('cem', presence('focusing', 3 * MIN)),
  ]

  it('yalnızca odaktakiler; bayat ve null durum çevrimdışı; tr-TR sıralı (c < ç, o < ö)', () => {
    expect(focusingFriends(friends, NOW).map((f) => f.username)).toEqual([
      'cem',
      'Çağla',
      'oya',
      'ömer',
      'zeynep',
    ])
  })

  it('girdi nesnelerini (genel tip) aynen döndürür ve girdiyi değiştirmez', () => {
    const before = friends.map((f) => f.username)
    const [first] = focusingFriends(friends, NOW)
    expect(first).toBe(friends[8])
    expect(friends.map((f) => f.username)).toEqual(before)
  })

  it('boş → boş', () => {
    expect(focusingFriends([], NOW)).toEqual([])
  })
})
