import { describe, expect, it } from 'vitest'
import type { ISODate, RecurrenceRule, Task, TaskCompletion, Weekday } from '../types'
import {
  COMPLETION_RATE_WINDOW_DAYS,
  UPCOMING_HORIZON_DAYS,
  addDays,
  agendaForDay,
  assignmentCompletionDay,
  completionRate,
  daysBetween,
  daysUntilDue,
  findCompletion,
  isCompletedOn,
  isDueOn,
  isOverdue,
  isScheduledOn,
  overdueAssignments,
  routineStartDate,
  routineStreak,
  tasksForDay,
  weekdayOf,
} from './tasks'

// Referans gün: 2026-11-19 Perşembe (ISO hafta günü 4).
const TODAY = '2026-11-19'
const DELETED_AT = '2026-11-20T00:00:00.000Z'

/**
 * YEREL saatle bir an üretir ve ISODateTime'a çevirir. Testler hangi saat diliminde koşarsa
 * koşsun bu anın yerel günü (y, m, d) olur.
 */
function local(y: number, m: number, d: number, h = 12, min = 0): string {
  return new Date(y, m - 1, d, h, min).toISOString()
}

const DAILY: RecurrenceRule = { frequency: 'daily', weekdays: [] }
const weekly = (...weekdays: Weekday[]): RecurrenceRule => ({ frequency: 'weekly', weekdays })

let idCounter = 0

function makeTask(overrides: Partial<Task> = {}): Task {
  idCounter += 1
  return {
    id: `task-${idCounter}`,
    createdAt: local(2026, 11, 1),
    updatedAt: local(2026, 11, 1),
    deletedAt: null,
    title: 'Görev',
    kind: 'routine',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: DAILY,
    completedAt: null,
    order: 0,
    ...overrides,
  }
}

function makeAssignment(overrides: Partial<Task> = {}): Task {
  return makeTask({ kind: 'assignment', recurrence: null, ...overrides })
}

function makeCompletion(overrides: Partial<TaskCompletion> = {}): TaskCompletion {
  idCounter += 1
  const date = overrides.date ?? TODAY
  const [y, m, d] = date.split('-').map(Number) as [number, number, number]
  return {
    id: `completion-${idCounter}`,
    createdAt: local(y, m, d),
    updatedAt: local(y, m, d),
    deletedAt: null,
    taskId: 'routine',
    date,
    completedAt: local(y, m, d),
    ...overrides,
  }
}

/** Bir rutin için verilen günlerin tamamlamaları. */
function completionsOn(taskId: string, days: ISODate[]): TaskCompletion[] {
  return days.map((date) => makeCompletion({ taskId, date }))
}

const titles = (tasks: Task[]): string[] => tasks.map((t) => t.title)

// ---------------------------------------------------------------------------
// Gün aritmetiği
// ---------------------------------------------------------------------------

describe('weekdayOf', () => {
  it.each<{ name: string; day: ISODate; expected: Weekday }>([
    { name: 'Pazartesi', day: '2026-11-16', expected: 1 },
    { name: 'Salı', day: '2026-11-17', expected: 2 },
    { name: 'Çarşamba', day: '2026-11-18', expected: 3 },
    { name: 'Perşembe (referans gün)', day: '2026-11-19', expected: 4 },
    { name: 'Cuma', day: '2026-11-20', expected: 5 },
    { name: 'Cumartesi', day: '2026-11-21', expected: 6 },
    { name: 'Pazar → 7 (JS 0 değil)', day: '2026-11-22', expected: 7 },
    { name: 'artık gün 2028-02-29 Salı', day: '2028-02-29', expected: 2 },
    { name: 'yılbaşı 2027-01-01 Cuma', day: '2027-01-01', expected: 5 },
  ])('$name: $day → $expected', ({ day, expected }) => {
    expect(weekdayOf(day)).toBe(expected)
  })
})

describe('addDays', () => {
  it.each<{ name: string; day: ISODate; amount: number; expected: ISODate }>([
    { name: 'sıfır gün', day: '2026-11-19', amount: 0, expected: '2026-11-19' },
    { name: 'bir gün ileri', day: '2026-11-19', amount: 1, expected: '2026-11-20' },
    { name: 'bir gün geri', day: '2026-11-19', amount: -1, expected: '2026-11-18' },
    { name: 'ay sonu → ay başı', day: '2026-11-30', amount: 1, expected: '2026-12-01' },
    { name: 'ay başı → önceki ay sonu', day: '2026-12-01', amount: -1, expected: '2026-11-30' },
    { name: 'yıl sonu → yılbaşı', day: '2026-12-31', amount: 1, expected: '2027-01-01' },
    { name: 'yılbaşı → yıl sonu', day: '2027-01-01', amount: -1, expected: '2026-12-31' },
    { name: 'artık yıl 28 Şub → 29 Şub', day: '2028-02-28', amount: 1, expected: '2028-02-29' },
    { name: 'artık yıl 29 Şub → 1 Mart', day: '2028-02-29', amount: 1, expected: '2028-03-01' },
    {
      name: 'artık olmayan yıl 28 Şub → 1 Mart',
      day: '2027-02-28',
      amount: 1,
      expected: '2027-03-01',
    },
    {
      name: 'Pazar → Pazartesi (hafta devri)',
      day: '2026-11-22',
      amount: 1,
      expected: '2026-11-23',
    },
    {
      name: 'yaz saati geçişi (Mart) etkisiz',
      day: '2027-03-27',
      amount: 2,
      expected: '2027-03-29',
    },
    { name: 'büyük ileri atlama (365)', day: '2027-01-01', amount: 365, expected: '2028-01-01' },
    { name: 'artık yılda 366 gün', day: '2028-01-01', amount: 366, expected: '2029-01-01' },
  ])('$name: $day + $amount → $expected', ({ day, amount, expected }) => {
    expect(addDays(day, amount)).toBe(expected)
  })
})

describe('daysBetween', () => {
  it.each<{ name: string; from: ISODate; to: ISODate; expected: number }>([
    { name: 'aynı gün', from: '2026-11-19', to: '2026-11-19', expected: 0 },
    { name: 'ertesi gün', from: '2026-11-19', to: '2026-11-20', expected: 1 },
    { name: 'önceki gün (negatif)', from: '2026-11-19', to: '2026-11-18', expected: -1 },
    { name: 'yıl devri', from: '2026-12-31', to: '2027-01-01', expected: 1 },
    { name: 'artık yıl Şubat', from: '2028-02-28', to: '2028-03-01', expected: 2 },
    { name: 'artık olmayan yıl Şubat', from: '2027-02-28', to: '2027-03-01', expected: 1 },
    { name: 'yaz saati geçişi (Ekim) tam gün', from: '2026-10-24', to: '2026-10-26', expected: 2 },
  ])('$name: $from → $to = $expected', ({ from, to, expected }) => {
    expect(daysBetween(from, to)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// Tekrar kuralı ve planlama
// ---------------------------------------------------------------------------

describe('isDueOn', () => {
  it.each<{ name: string; rule: RecurrenceRule; day: ISODate; expected: boolean }>([
    { name: 'daily her gün (Perşembe)', rule: DAILY, day: '2026-11-19', expected: true },
    { name: 'daily her gün (Pazar)', rule: DAILY, day: '2026-11-22', expected: true },
    {
      name: 'weekly Pzt-Çar-Cum, Çarşamba',
      rule: weekly(1, 3, 5),
      day: '2026-11-18',
      expected: true,
    },
    {
      name: 'weekly Pzt-Çar-Cum, Perşembe',
      rule: weekly(1, 3, 5),
      day: '2026-11-19',
      expected: false,
    },
    { name: 'weekly Pazar, Pazar', rule: weekly(7), day: '2026-11-22', expected: true },
    {
      name: 'weekly Pazar, sonraki Pazartesi',
      rule: weekly(7),
      day: '2026-11-23',
      expected: false,
    },
    { name: 'weekly Pazartesi, sonraki hafta', rule: weekly(1), day: '2026-11-30', expected: true },
    {
      name: 'weekly boş weekdays → hiçbir gün',
      rule: weekly(),
      day: '2026-11-19',
      expected: false,
    },
  ])('$name → $expected', ({ rule, day, expected }) => {
    expect(isDueOn(rule, day)).toBe(expected)
  })
})

describe('routineStartDate', () => {
  it.each<{ name: string; task: Task; expected: ISODate }>([
    {
      name: 'startDate yok → createdAt yerel günü',
      task: makeTask({ createdAt: local(2026, 11, 10) }),
      expected: '2026-11-10',
    },
    {
      name: 'startDate null → createdAt yerel günü',
      task: makeTask({ createdAt: local(2026, 11, 10), startDate: null }),
      expected: '2026-11-10',
    },
    {
      name: 'createdAt yerel 23:59 → aynı gün',
      task: makeTask({ createdAt: local(2026, 11, 10, 23, 59) }),
      expected: '2026-11-10',
    },
    {
      name: 'createdAt yerel 00:00 → o gün',
      task: makeTask({ createdAt: local(2026, 11, 11, 0, 0) }),
      expected: '2026-11-11',
    },
    {
      name: "startDate createdAt'ten önce → startDate",
      task: makeTask({ createdAt: local(2026, 11, 10), startDate: '2026-11-01' }),
      expected: '2026-11-01',
    },
    {
      name: "startDate createdAt'ten sonra → startDate",
      task: makeTask({ createdAt: local(2026, 11, 10), startDate: '2026-11-15' }),
      expected: '2026-11-15',
    },
  ])('$name', ({ task, expected }) => {
    expect(routineStartDate(task)).toBe(expected)
  })
})

describe('isScheduledOn', () => {
  it.each<{ name: string; task: Task; day: ISODate; expected: boolean }>([
    { name: 'günlük rutin, başlangıçtan sonra', task: makeTask(), day: TODAY, expected: true },
    {
      name: 'günlük rutin, tam başlangıç günü',
      task: makeTask({ createdAt: local(2026, 11, 19, 23, 59) }),
      day: TODAY,
      expected: true,
    },
    {
      name: 'oluşturulmadan önceki gün planlı değil',
      task: makeTask({ createdAt: local(2026, 11, 19, 0, 0) }),
      day: '2026-11-18',
      expected: false,
    },
    {
      name: "startDate'ten önceki gün planlı değil",
      task: makeTask({ startDate: '2026-11-20' }),
      day: TODAY,
      expected: false,
    },
    {
      name: 'startDate oluşturmadan önce: geriye dönük planlı',
      task: makeTask({ createdAt: local(2026, 11, 19), startDate: '2026-11-10' }),
      day: '2026-11-12',
      expected: true,
    },
    {
      name: 'haftalık, gün eşleşiyor',
      task: makeTask({ recurrence: weekly(4) }),
      day: TODAY,
      expected: true,
    },
    {
      name: 'haftalık, gün eşleşmiyor',
      task: makeTask({ recurrence: weekly(1) }),
      day: TODAY,
      expected: false,
    },
    {
      name: 'haftalık boş weekdays',
      task: makeTask({ recurrence: weekly() }),
      day: TODAY,
      expected: false,
    },
    { name: 'recurrence null', task: makeTask({ recurrence: null }), day: TODAY, expected: false },
    {
      name: 'silinmiş rutin',
      task: makeTask({ deletedAt: DELETED_AT }),
      day: TODAY,
      expected: false,
    },
    {
      name: 'ödev hiçbir zaman planlı değil',
      task: makeAssignment({ dueDate: TODAY, recurrence: DAILY }),
      day: TODAY,
      expected: false,
    },
  ])('$name → $expected', ({ task, day, expected }) => {
    expect(isScheduledOn(task, day)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// Tamamlama
// ---------------------------------------------------------------------------

describe('assignmentCompletionDay', () => {
  it.each<{ name: string; task: Task; expected: ISODate | null }>([
    { name: 'tamamlanmamış ödev', task: makeAssignment(), expected: null },
    {
      name: 'yerel 23:59 tamamlandı → aynı gün',
      task: makeAssignment({ completedAt: local(2026, 11, 19, 23, 59) }),
      expected: '2026-11-19',
    },
    {
      name: 'yerel 00:00 tamamlandı → yeni gün',
      task: makeAssignment({ completedAt: local(2026, 11, 20, 0, 0) }),
      expected: '2026-11-20',
    },
    {
      name: 'rutin (completedAt dolu olsa bile) → null',
      task: makeTask({ completedAt: local(2026, 11, 19) }),
      expected: null,
    },
  ])('$name', ({ task, expected }) => {
    expect(assignmentCompletionDay(task)).toBe(expected)
  })
})

describe('findCompletion', () => {
  const early = makeCompletion({ taskId: 'r', date: TODAY, completedAt: local(2026, 11, 19, 8) })
  const late = makeCompletion({ taskId: 'r', date: TODAY, completedAt: local(2026, 11, 19, 20) })
  const deletedEarliest = makeCompletion({
    taskId: 'r',
    date: TODAY,
    completedAt: local(2026, 11, 19, 6),
    deletedAt: DELETED_AT,
  })
  const otherTask = makeCompletion({ taskId: 'x', date: TODAY })
  const otherDay = makeCompletion({ taskId: 'r', date: '2026-11-18' })

  it.each<{ name: string; completions: TaskCompletion[]; expected: TaskCompletion | undefined }>([
    { name: 'boş liste', completions: [], expected: undefined },
    { name: 'tek eşleşme', completions: [late], expected: late },
    { name: 'kopyalar → en erken completedAt', completions: [late, early], expected: early },
    { name: 'kopyalar (ters sıra) → en erken', completions: [early, late], expected: early },
    {
      name: 'silinmiş (daha erken) tamamlama yok sayılır',
      completions: [deletedEarliest, late],
      expected: late,
    },
    { name: 'yalnızca silinmiş → yok', completions: [deletedEarliest], expected: undefined },
    {
      name: 'başka görev / başka gün → yok',
      completions: [otherTask, otherDay],
      expected: undefined,
    },
  ])('$name', ({ completions, expected }) => {
    expect(findCompletion(completions, 'r', TODAY)).toBe(expected)
  })
})

describe('isCompletedOn', () => {
  const routine = makeTask({ id: 'r' })
  const done = makeCompletion({ taskId: 'r', date: TODAY })
  const deletedDone = makeCompletion({ taskId: 'r', date: TODAY, deletedAt: DELETED_AT })

  it.each<{
    name: string
    task: Task
    completions: TaskCompletion[]
    day: ISODate
    expected: boolean
  }>([
    {
      name: 'rutin, o gün tamamlanmış',
      task: routine,
      completions: [done],
      day: TODAY,
      expected: true,
    },
    { name: 'rutin, tamamlama yok', task: routine, completions: [], day: TODAY, expected: false },
    {
      name: 'rutin, başka günün tamamlaması',
      task: routine,
      completions: [done],
      day: '2026-11-18',
      expected: false,
    },
    {
      name: 'rutin, yalnızca silinmiş tamamlama',
      task: routine,
      completions: [deletedDone],
      day: TODAY,
      expected: false,
    },
    {
      name: 'rutin, kopya tamamlamalar',
      task: routine,
      completions: [done, makeCompletion({ taskId: 'r', date: TODAY })],
      day: TODAY,
      expected: true,
    },
    {
      name: 'silinmiş rutin',
      task: makeTask({ id: 'r', deletedAt: DELETED_AT }),
      completions: [done],
      day: TODAY,
      expected: false,
    },
    { name: 'ödev, açık', task: makeAssignment(), completions: [], day: TODAY, expected: false },
    {
      name: 'ödev, aynı gün (23:59) tamamlandı',
      task: makeAssignment({ completedAt: local(2026, 11, 19, 23, 59) }),
      completions: [],
      day: TODAY,
      expected: true,
    },
    {
      name: 'ödev, önceki gün tamamlandı',
      task: makeAssignment({ completedAt: local(2026, 11, 18) }),
      completions: [],
      day: TODAY,
      expected: true,
    },
    {
      name: 'ödev, ertesi gün 00:00 tamamlandı → o gün için değil',
      task: makeAssignment({ completedAt: local(2026, 11, 20, 0, 0) }),
      completions: [],
      day: TODAY,
      expected: false,
    },
    {
      name: 'silinmiş ödev',
      task: makeAssignment({ completedAt: local(2026, 11, 18), deletedAt: DELETED_AT }),
      completions: [],
      day: TODAY,
      expected: false,
    },
  ])('$name → $expected', ({ task, completions, day, expected }) => {
    expect(isCompletedOn(task, completions, day)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// Ödev son tarihleri
// ---------------------------------------------------------------------------

describe('isOverdue', () => {
  it.each<{ name: string; task: Task; expected: boolean }>([
    {
      name: 'dün son tarihli, açık',
      task: makeAssignment({ dueDate: '2026-11-18' }),
      expected: true,
    },
    { name: 'bugün son tarihli', task: makeAssignment({ dueDate: TODAY }), expected: false },
    { name: 'yarın son tarihli', task: makeAssignment({ dueDate: '2026-11-20' }), expected: false },
    { name: 'son tarih yok', task: makeAssignment({ dueDate: null }), expected: false },
    {
      name: 'dün son tarihli ama tamamlanmış',
      task: makeAssignment({ dueDate: '2026-11-18', completedAt: local(2026, 11, 19) }),
      expected: false,
    },
    {
      name: 'silinmiş',
      task: makeAssignment({ dueDate: '2026-11-18', deletedAt: DELETED_AT }),
      expected: false,
    },
    {
      name: 'rutin (dueDate olsa bile)',
      task: makeTask({ dueDate: '2026-11-18' }),
      expected: false,
    },
  ])('$name → $expected', ({ task, expected }) => {
    expect(isOverdue(task, TODAY)).toBe(expected)
  })
})

describe('overdueAssignments', () => {
  it('yalnızca gecikenleri döner; en eski son tarih önce, eşitlikte order sonra title (tr-TR)', () => {
    const tasks = [
      makeAssignment({ title: 'Dün B', dueDate: '2026-11-18', order: 1 }),
      makeAssignment({ title: 'Geçen hafta', dueDate: '2026-11-12', order: 5 }),
      makeAssignment({ title: 'Dün A', dueDate: '2026-11-18', order: 1 }),
      makeAssignment({ title: 'Dün sıra 0', dueDate: '2026-11-18', order: 0 }),
      makeAssignment({ title: 'İngilizce', dueDate: '2026-11-17' }),
      makeAssignment({ title: 'Isı', dueDate: '2026-11-17' }),
      makeAssignment({ title: 'Bugün', dueDate: TODAY }),
      makeAssignment({ title: 'Bitti', dueDate: '2026-11-10', completedAt: local(2026, 11, 11) }),
      makeAssignment({ title: 'Silindi', dueDate: '2026-11-10', deletedAt: DELETED_AT }),
      makeTask({ title: 'Rutin' }),
    ]
    const input = [...tasks]

    const result = overdueAssignments(tasks, TODAY)

    // tr-TR: "I" < "İ" (Türk alfabesi: ... H, I, İ, J ...)
    expect(titles(result)).toEqual([
      'Geçen hafta',
      'Isı',
      'İngilizce',
      'Dün sıra 0',
      'Dün A',
      'Dün B',
    ])
    expect(tasks).toEqual(input) // girdi mutasyona uğramaz
  })

  it('boş liste → boş', () => {
    expect(overdueAssignments([], TODAY)).toEqual([])
  })
})

describe('daysUntilDue', () => {
  it.each<{ name: string; task: Task; expected: number | null }>([
    { name: 'bugün → 0', task: makeAssignment({ dueDate: TODAY }), expected: 0 },
    { name: 'yarın → 1', task: makeAssignment({ dueDate: '2026-11-20' }), expected: 1 },
    { name: 'dün → -1', task: makeAssignment({ dueDate: '2026-11-18' }), expected: -1 },
    { name: 'ay devri', task: makeAssignment({ dueDate: '2026-12-01' }), expected: 12 },
    { name: 'son tarih yok → null', task: makeAssignment({ dueDate: null }), expected: null },
    { name: 'rutin → null', task: makeTask({ dueDate: TODAY }), expected: null },
  ])('$name', ({ task, expected }) => {
    expect(daysUntilDue(task, TODAY)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// Gündem
// ---------------------------------------------------------------------------

describe('agendaForDay', () => {
  type Group = 'routines' | 'overdue' | 'dueToday' | 'upcoming' | 'none'

  it.each<{ name: string; task: Task; expected: Group }>([
    // Rutinler
    { name: 'günlük rutin', task: makeTask(), expected: 'routines' },
    {
      name: 'haftalık rutin, bugün değil',
      task: makeTask({ recurrence: weekly(1) }),
      expected: 'none',
    },
    {
      name: 'rutin, başlangıçtan önce',
      task: makeTask({ startDate: '2026-11-20' }),
      expected: 'none',
    },
    { name: 'silinmiş rutin', task: makeTask({ deletedAt: DELETED_AT }), expected: 'none' },
    // Açık ödevler — aralık
    {
      name: 'açık, dün son tarihli',
      task: makeAssignment({ dueDate: '2026-11-18' }),
      expected: 'overdue',
    },
    {
      name: 'açık, çok eski son tarih',
      task: makeAssignment({ dueDate: '2025-01-01' }),
      expected: 'overdue',
    },
    {
      name: 'açık, bugün son tarihli',
      task: makeAssignment({ dueDate: TODAY }),
      expected: 'dueToday',
    },
    { name: 'açık, son tarih yok', task: makeAssignment({ dueDate: null }), expected: 'dueToday' },
    { name: 'açık, yarın', task: makeAssignment({ dueDate: '2026-11-20' }), expected: 'upcoming' },
    {
      name: 'ufuk sınırı: tam gün+7 dahil',
      task: makeAssignment({ dueDate: '2026-11-26' }),
      expected: 'upcoming',
    },
    {
      name: 'ufuk sınırı: gün+8 hariç',
      task: makeAssignment({ dueDate: '2026-11-27' }),
      expected: 'none',
    },
    // Tamamlanma günü
    {
      name: 'bugün (23:59) tamamlanan, bugün son tarihli → listede kalır',
      task: makeAssignment({ dueDate: TODAY, completedAt: local(2026, 11, 19, 23, 59) }),
      expected: 'dueToday',
    },
    {
      name: 'bugün tamamlanan, geciken → listede kalır',
      task: makeAssignment({ dueDate: '2026-11-15', completedAt: local(2026, 11, 19) }),
      expected: 'overdue',
    },
    {
      name: 'bugün tamamlanan, yaklaşan → listede kalır',
      task: makeAssignment({ dueDate: '2026-11-22', completedAt: local(2026, 11, 19) }),
      expected: 'upcoming',
    },
    {
      name: 'bugün tamamlanan ama ufuk dışı → hariç',
      task: makeAssignment({ dueDate: '2026-12-31', completedAt: local(2026, 11, 19) }),
      expected: 'none',
    },
    {
      name: 'dün (23:59) tamamlanan → hariç',
      task: makeAssignment({ dueDate: TODAY, completedAt: local(2026, 11, 18, 23, 59) }),
      expected: 'none',
    },
    {
      name: 'tarihsiz, önceki gün tamamlanan → hariç',
      task: makeAssignment({ dueDate: null, completedAt: local(2026, 11, 10) }),
      expected: 'none',
    },
    {
      name: 'sonraki gün (00:00) tamamlanan → o gün açıktı, dahil',
      task: makeAssignment({ dueDate: TODAY, completedAt: local(2026, 11, 20, 0, 0) }),
      expected: 'dueToday',
    },
    {
      name: 'silinmiş açık ödev',
      task: makeAssignment({ dueDate: TODAY, deletedAt: DELETED_AT }),
      expected: 'none',
    },
  ])('$name → $expected', ({ task, expected }) => {
    const agenda = agendaForDay([task], TODAY)
    const groups: Group[] = (['routines', 'overdue', 'dueToday', 'upcoming'] as const).filter((g) =>
      agenda[g].includes(task),
    )
    expect(groups).toEqual(expected === 'none' ? [] : [expected])
  })

  it('her grubu kendi içinde sıralar', () => {
    const tasks = [
      makeTask({ title: 'Rutin B', order: 1 }),
      makeTask({ title: 'Rutin A', order: 1 }),
      makeTask({ title: 'Rutin sıra 0', order: 0 }),
      makeAssignment({ title: 'Gecikmiş yeni', dueDate: '2026-11-18' }),
      makeAssignment({ title: 'Gecikmiş eski', dueDate: '2026-11-10', order: 9 }),
      makeAssignment({ title: 'Tarihsiz sıra 0', dueDate: null, order: 0 }),
      makeAssignment({ title: 'Bugün sıra 2', dueDate: TODAY, order: 2 }),
      makeAssignment({ title: 'Tarihsiz sıra 1', dueDate: null, order: 1 }),
      makeAssignment({ title: 'Bugün sıra 1', dueDate: TODAY, order: 1 }),
      makeAssignment({ title: 'Yaklaşan uzak', dueDate: '2026-11-25' }),
      makeAssignment({ title: 'Yaklaşan yakın', dueDate: '2026-11-20', order: 3 }),
    ]

    const agenda = agendaForDay(tasks, TODAY)

    expect(titles(agenda.routines)).toEqual(['Rutin sıra 0', 'Rutin A', 'Rutin B'])
    expect(titles(agenda.overdue)).toEqual(['Gecikmiş eski', 'Gecikmiş yeni'])
    // Önce son tarihi bugün olanlar, sonra tarihsizler (her biri order/title).
    expect(titles(agenda.dueToday)).toEqual([
      'Bugün sıra 1',
      'Bugün sıra 2',
      'Tarihsiz sıra 0',
      'Tarihsiz sıra 1',
    ])
    expect(titles(agenda.upcoming)).toEqual(['Yaklaşan yakın', 'Yaklaşan uzak'])
  })

  it.each<{ name: string; horizonDays: number | undefined; dueDate: ISODate; included: boolean }>([
    {
      name: 'varsayılan ufuk (7): gün+7 dahil',
      horizonDays: undefined,
      dueDate: '2026-11-26',
      included: true,
    },
    {
      name: 'varsayılan ufuk (7): gün+8 hariç',
      horizonDays: undefined,
      dueDate: '2026-11-27',
      included: false,
    },
    { name: 'ufuk 0: yarın hariç', horizonDays: 0, dueDate: '2026-11-20', included: false },
    {
      name: 'ufuk 14: gün+14 dahil (ay devri)',
      horizonDays: 14,
      dueDate: '2026-12-03',
      included: true,
    },
  ])('$name', ({ horizonDays, dueDate, included }) => {
    const task = makeAssignment({ dueDate })
    const agenda =
      horizonDays === undefined
        ? agendaForDay([task], TODAY)
        : agendaForDay([task], TODAY, horizonDays)
    expect(agenda.upcoming.includes(task)).toBe(included)
  })

  it('varsayılan ufuk UPCOMING_HORIZON_DAYS = 7', () => {
    expect(UPCOMING_HORIZON_DAYS).toBe(7)
  })

  it('boş liste → boş gruplar', () => {
    expect(agendaForDay([], TODAY)).toEqual({
      routines: [],
      overdue: [],
      dueToday: [],
      upcoming: [],
    })
  })
})

describe('tasksForDay', () => {
  it('rutinler, gecikenler, bugünkü ve yaklaşan ödevler sırasıyla birleşir', () => {
    const tasks = [
      makeAssignment({ title: 'Yaklaşan', dueDate: '2026-11-21' }),
      makeAssignment({ title: 'Bugün', dueDate: TODAY }),
      makeAssignment({ title: 'Gecikmiş', dueDate: '2026-11-17' }),
      makeTask({ title: 'Rutin' }),
      makeAssignment({ title: 'Ufuk dışı', dueDate: '2026-12-31' }),
      makeAssignment({ title: 'Silinmiş', dueDate: TODAY, deletedAt: DELETED_AT }),
    ]
    expect(titles(tasksForDay(tasks, TODAY))).toEqual(['Rutin', 'Gecikmiş', 'Bugün', 'Yaklaşan'])
  })
})

// ---------------------------------------------------------------------------
// Seri ve oran
// ---------------------------------------------------------------------------

describe('routineStreak', () => {
  // Varsayılan rutin 2026-11-01'de oluşturuldu (günlük).
  it.each<{
    name: string
    task: Task
    done: ISODate[]
    extra?: TaskCompletion[]
    expected: number
  }>([
    { name: 'hiç tamamlama yok', task: makeTask({ id: 'r' }), done: [], expected: 0 },
    {
      name: 'bugün dahil 3 gün üst üste',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-17', '2026-11-18', '2026-11-19'],
      expected: 3,
    },
    {
      name: 'bugün henüz yapılmadı → seri bozulmaz, dünden sayılır',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-17', '2026-11-18'],
      expected: 2,
    },
    {
      name: 'dün kaçırıldı → seri yalnızca bugün',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-16', '2026-11-17', '2026-11-19'],
      expected: 1,
    },
    {
      name: 'bugün ve dün yapılmadı → 0',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-16', '2026-11-17'],
      expected: 0,
    },
    {
      name: 'başlangıç gününde durur (öncesine bakılmaz)',
      task: makeTask({ id: 'r', createdAt: local(2026, 11, 17, 23, 59) }),
      done: ['2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18', '2026-11-19'],
      expected: 3,
    },
    {
      name: 'startDate öncesi tamamlamalar sayılmaz',
      task: makeTask({ id: 'r', startDate: '2026-11-18' }),
      done: ['2026-11-17', '2026-11-18', '2026-11-19'],
      expected: 2,
    },
    {
      name: 'başlangıç bugünden sonra → 0',
      task: makeTask({ id: 'r', startDate: '2026-11-20' }),
      done: ['2026-11-19'],
      expected: 0,
    },
    {
      name: 'haftalık Pzt-Çar-Cum: planlı olmayan günlerdeki boşluklar seriyi bozmaz',
      // Bugün Perşembe (planlı değil). Çar 18, Pzt 16, Cum 13, Çar 11 yapıldı; Pzt 9 kaçırıldı.
      task: makeTask({ id: 'r', recurrence: weekly(1, 3, 5) }),
      done: ['2026-11-11', '2026-11-13', '2026-11-16', '2026-11-18'],
      expected: 4,
    },
    {
      name: 'haftalık Pazar: hafta devri boyunca (Pazar → Pazartesi) sayılır',
      task: makeTask({ id: 'r', recurrence: weekly(7) }),
      done: ['2026-11-08', '2026-11-15'],
      expected: 2,
    },
    {
      name: 'haftalık Perşembe: bugün planlı ama yapılmadı → geçen haftadan sayılır',
      task: makeTask({ id: 'r', recurrence: weekly(4) }),
      done: ['2026-11-05', '2026-11-12'],
      expected: 2,
    },
    {
      name: 'planlı olmayan günde tamamlama seriye eklenmez',
      task: makeTask({ id: 'r', recurrence: weekly(3) }),
      done: ['2026-11-17', '2026-11-18'],
      expected: 1,
    },
    {
      name: 'haftalık boş weekdays → 0',
      task: makeTask({ id: 'r', recurrence: weekly() }),
      done: ['2026-11-18', '2026-11-19'],
      expected: 0,
    },
    {
      name: 'kopya tamamlamalar tek sayılır',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-18', '2026-11-18', '2026-11-19', '2026-11-19'],
      expected: 2,
    },
    {
      name: 'silinmiş tamamlama seriyi kırar',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-17', '2026-11-19'],
      extra: [makeCompletion({ taskId: 'r', date: '2026-11-18', deletedAt: DELETED_AT })],
      expected: 1,
    },
    {
      name: 'başka görevin tamamlaması sayılmaz',
      task: makeTask({ id: 'r' }),
      done: [],
      extra: [makeCompletion({ taskId: 'x', date: TODAY })],
      expected: 0,
    },
    {
      name: 'ay devri boyunca seri',
      task: makeTask({ id: 'r', createdAt: local(2026, 10, 1) }),
      done: ['2026-10-30', '2026-10-31', '2026-11-01'],
      expected: 0, // 2026-11-02 … 19 kaçırıldı
    },
    {
      name: 'silinmiş rutin → 0',
      task: makeTask({ id: 'r', deletedAt: DELETED_AT }),
      done: ['2026-11-19'],
      expected: 0,
    },
    {
      name: 'recurrence null → 0',
      task: makeTask({ id: 'r', recurrence: null }),
      done: ['2026-11-19'],
      expected: 0,
    },
    {
      name: 'ödev → 0',
      task: makeAssignment({ id: 'r' }),
      done: ['2026-11-19'],
      expected: 0,
    },
  ])('$name → $expected', ({ task, done, extra = [], expected }) => {
    const completions = [...completionsOn('r', done), ...extra]
    expect(routineStreak(task, completions, TODAY)).toBe(expected)
  })

  it('ay/yıl devri boyunca kesintisiz seri', () => {
    const task = makeTask({ id: 'r', startDate: '2026-12-30' })
    const done = ['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02']
    expect(routineStreak(task, completionsOn('r', done), '2027-01-02')).toBe(4)
  })
})

describe('completionRate', () => {
  it.each<{
    name: string
    task: Task
    done: ISODate[]
    extra?: TaskCompletion[]
    windowDays?: number
    expected: { scheduled: number; completed: number; rate: number | null }
  }>([
    {
      name: "günlük, 7 günün 7'si",
      task: makeTask({ id: 'r' }),
      done: [
        '2026-11-13',
        '2026-11-14',
        '2026-11-15',
        '2026-11-16',
        '2026-11-17',
        '2026-11-18',
        '2026-11-19',
      ],
      expected: { scheduled: 7, completed: 7, rate: 1 },
    },
    {
      name: 'günlük, hiç tamamlama yok',
      task: makeTask({ id: 'r' }),
      done: [],
      expected: { scheduled: 7, completed: 0, rate: 0 },
    },
    {
      name: 'pencere dışı (today−7) tamamlama sayılmaz',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-12', '2026-11-19'],
      expected: { scheduled: 7, completed: 1, rate: 1 / 7 },
    },
    {
      name: 'bugün planlı ve yapılmadı → paydada sayılır',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-13', '2026-11-14', '2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18'],
      expected: { scheduled: 7, completed: 6, rate: 6 / 7 },
    },
    {
      name: 'başlangıçtan önceki günler hariç',
      task: makeTask({ id: 'r', createdAt: local(2026, 11, 17, 23, 59) }),
      done: ['2026-11-15', '2026-11-17', '2026-11-19'],
      expected: { scheduled: 3, completed: 2, rate: 2 / 3 },
    },
    {
      name: 'haftalık Pzt-Çar-Cum (pencere 13–19 Kasım)',
      task: makeTask({ id: 'r', recurrence: weekly(1, 3, 5) }),
      done: ['2026-11-13', '2026-11-16', '2026-11-17'],
      expected: { scheduled: 3, completed: 2, rate: 2 / 3 },
    },
    {
      name: 'kopya tamamlamalar tek sayılır',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-19', '2026-11-19', '2026-11-19'],
      expected: { scheduled: 7, completed: 1, rate: 1 / 7 },
    },
    {
      name: 'silinmiş tamamlama sayılmaz',
      task: makeTask({ id: 'r' }),
      done: [],
      extra: [makeCompletion({ taskId: 'r', date: TODAY, deletedAt: DELETED_AT })],
      expected: { scheduled: 7, completed: 0, rate: 0 },
    },
    {
      name: 'özel pencere 3 gün',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-16', '2026-11-18'],
      windowDays: 3,
      expected: { scheduled: 3, completed: 1, rate: 1 / 3 },
    },
    {
      name: 'pencere 0 → planlı gün yok, oran null',
      task: makeTask({ id: 'r' }),
      done: ['2026-11-19'],
      windowDays: 0,
      expected: { scheduled: 0, completed: 0, rate: null },
    },
    {
      name: 'başlangıç bugünden sonra → oran null',
      task: makeTask({ id: 'r', startDate: '2026-11-20' }),
      done: [],
      expected: { scheduled: 0, completed: 0, rate: null },
    },
    {
      name: 'haftalık boş weekdays → oran null',
      task: makeTask({ id: 'r', recurrence: weekly() }),
      done: ['2026-11-19'],
      expected: { scheduled: 0, completed: 0, rate: null },
    },
    {
      name: 'silinmiş rutin → oran null',
      task: makeTask({ id: 'r', deletedAt: DELETED_AT }),
      done: ['2026-11-19'],
      expected: { scheduled: 0, completed: 0, rate: null },
    },
    {
      name: 'ödev → oran null',
      task: makeAssignment({ id: 'r' }),
      done: ['2026-11-19'],
      expected: { scheduled: 0, completed: 0, rate: null },
    },
  ])('$name', ({ task, done, extra = [], windowDays, expected }) => {
    const completions = [...completionsOn('r', done), ...extra]
    const result =
      windowDays === undefined
        ? completionRate(task, completions, TODAY)
        : completionRate(task, completions, TODAY, windowDays)
    expect(result.scheduled).toBe(expected.scheduled)
    expect(result.completed).toBe(expected.completed)
    if (expected.rate === null) expect(result.rate).toBeNull()
    else expect(result.rate).toBeCloseTo(expected.rate, 10)
  })

  it('varsayılan pencere COMPLETION_RATE_WINDOW_DAYS = 7', () => {
    expect(COMPLETION_RATE_WINDOW_DAYS).toBe(7)
  })
})
