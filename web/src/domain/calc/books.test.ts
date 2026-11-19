import { describe, expect, it } from 'vitest'
import type { Book, BookProgress } from '../types'
import {
  PACE_WINDOW_DAYS,
  bookStatus,
  estimateDaysToFinish,
  groupBySubject,
  isBookCompleted,
  isFinished,
  knownTotal,
  latestProgress,
  progressRatio,
  sortProgressHistory,
  splitByFinished,
  summarizeBook,
  summarizeBooks,
  weeklyPace,
} from './books'

const NOW = new Date('2026-11-19T12:00:00.000Z')
const DAY_MS = 24 * 60 * 60 * 1000
const WINDOW_MS = PACE_WINDOW_DAYS * DAY_MS
const EPOCH = '2026-01-01T00:00:00.000Z'

/** `NOW` + offset (ms) → ISO. */
function at(offsetMs: number): string {
  return new Date(NOW.getTime() + offsetMs).toISOString()
}
function daysAgo(days: number): string {
  return at(-days * DAY_MS)
}

let counter = 0
function nextId(prefix: string): string {
  counter += 1
  return `${prefix}-${String(counter).padStart(4, '0')}`
}

function book(overrides: Partial<Book> = {}): Book {
  return {
    id: nextId('book'),
    createdAt: EPOCH,
    updatedAt: EPOCH,
    deletedAt: null,
    title: 'Kitap',
    publisher: null,
    kind: 'questionBank',
    subjectId: null,
    exam: null,
    unit: 'page',
    totalUnits: 100,
    archivedAt: null,
    ...overrides,
  } as Book
}

function entry(overrides: Partial<BookProgress> = {}): BookProgress {
  return {
    id: nextId('entry'),
    createdAt: EPOCH,
    updatedAt: EPOCH,
    deletedAt: null,
    bookId: 'book-x',
    reachedUnit: 0,
    topicId: null,
    recordedAt: EPOCH,
    note: null,
    ...overrides,
  }
}

/** Kısa yol: `daysAgo(d)` anında `reached` konumunda kayıt. */
function at_(daysBack: number, reached: number, extra: Partial<BookProgress> = {}): BookProgress {
  return entry({ recordedAt: daysAgo(daysBack), reachedUnit: reached, ...extra })
}

describe('knownTotal', () => {
  it.each([
    ['null', null, null],
    ['0', 0, null],
    ['negatif', -5, null],
    ['NaN', Number.NaN, null],
    ['Infinity', Number.POSITIVE_INFINITY, null],
    ['-Infinity', Number.NEGATIVE_INFINITY, null],
    ['küçük pozitif', 0.5, 0.5],
    ['normal', 320, 320],
  ])('totalUnits=%s → %s', (_name, totalUnits, expected) => {
    expect(knownTotal(book({ totalUnits }))).toBe(expected)
  })
})

describe('sortProgressHistory / latestProgress', () => {
  it('boş geçmiş: boş liste ve undefined', () => {
    expect(sortProgressHistory([])).toEqual([])
    expect(latestProgress([])).toBeUndefined()
  })

  it('en yeni önce sıralar ve silinmişleri atar', () => {
    const a = entry({ recordedAt: daysAgo(3), reachedUnit: 10 })
    const b = entry({ recordedAt: daysAgo(1), reachedUnit: 30 })
    const c = entry({ recordedAt: daysAgo(2), reachedUnit: 20 })
    const deleted = entry({ recordedAt: daysAgo(0), reachedUnit: 99, deletedAt: daysAgo(0) })

    const sorted = sortProgressHistory([a, deleted, b, c])

    expect(sorted.map((e) => e.id)).toEqual([b.id, c.id, a.id])
  })

  it('tüm kayıtlar silinmişse latest undefined', () => {
    const deleted = entry({ deletedAt: daysAgo(1) })
    expect(latestProgress([deleted])).toBeUndefined()
  })

  it('geri giden ilerlemede en son kayıt kazanır (daha küçük birim olsa da)', () => {
    const older = at_(5, 80)
    const newer = at_(1, 60)
    expect(latestProgress([older, newer])).toBe(newer)
    expect(latestProgress([newer, older])).toBe(newer)
  })

  it('recordedAt eşitliğinde createdAt daha yeni olan kazanır', () => {
    const first = entry({ recordedAt: daysAgo(1), createdAt: at(-3000), reachedUnit: 10 })
    const second = entry({ recordedAt: daysAgo(1), createdAt: at(-1000), reachedUnit: 20 })
    expect(latestProgress([first, second])).toBe(second)
    expect(latestProgress([second, first])).toBe(second)
  })

  it('gelecek tarihli kayıtlar latestProgress içinde filtrelenmez', () => {
    const past = at_(1, 10)
    const future = entry({ recordedAt: at(DAY_MS), reachedUnit: 50 })
    expect(latestProgress([past, future])).toBe(future)
  })

  it('girdi dizisini mutasyona uğratmaz', () => {
    const input = Object.freeze([at_(3, 10), at_(1, 30), at_(2, 20)])
    const snapshot = [...input]
    expect(() => sortProgressHistory(input)).not.toThrow()
    expect(() => latestProgress(input)).not.toThrow()
    expect([...input]).toEqual(snapshot)
  })
})

describe('progressRatio', () => {
  const cases: {
    name: string
    totalUnits: number | null
    reached: number | undefined
    expected: number | null
  }[] = [
    { name: 'toplam null → null', totalUnits: null, reached: 10, expected: null },
    { name: 'toplam 0 → null', totalUnits: 0, reached: 10, expected: null },
    { name: 'toplam negatif → null', totalUnits: -10, reached: 10, expected: null },
    { name: 'toplam NaN → null', totalUnits: Number.NaN, reached: 10, expected: null },
    {
      name: 'toplam Infinity → null',
      totalUnits: Number.POSITIVE_INFINITY,
      reached: 10,
      expected: null,
    },
    { name: 'kayıt yok → 0', totalUnits: 100, reached: undefined, expected: 0 },
    { name: 'yarısı', totalUnits: 200, reached: 50, expected: 0.25 },
    { name: 'tam bitti → 1', totalUnits: 100, reached: 100, expected: 1 },
    { name: 'toplamı aştı → 1 (sınırlı)', totalUnits: 100, reached: 150, expected: 1 },
    { name: 'negatif konum → 0 (sınırlı)', totalUnits: 100, reached: -20, expected: 0 },
  ]

  it.each(cases)('$name', ({ totalUnits, reached, expected }) => {
    const latest = reached === undefined ? undefined : entry({ reachedUnit: reached })
    expect(progressRatio(book({ totalUnits }), latest)).toBe(expected)
  })
})

describe('isBookCompleted', () => {
  const cases: {
    name: string
    totalUnits: number | null
    reached: number | undefined
    expected: boolean
  }[] = [
    { name: 'toplam bilinmiyor → asla bitmez', totalUnits: null, reached: 9999, expected: false },
    { name: 'toplam 0 → bitmez', totalUnits: 0, reached: 0, expected: false },
    { name: 'toplam negatif → bitmez', totalUnits: -1, reached: 5, expected: false },
    { name: 'toplam NaN → bitmez', totalUnits: Number.NaN, reached: 5, expected: false },
    {
      name: 'toplam Infinity → bitmez',
      totalUnits: Number.POSITIVE_INFINITY,
      reached: 5,
      expected: false,
    },
    { name: 'kayıt yok → bitmez', totalUnits: 100, reached: undefined, expected: false },
    { name: 'toplamdan az → bitmez', totalUnits: 100, reached: 99, expected: false },
    { name: 'tam toplam → biter', totalUnits: 100, reached: 100, expected: true },
    { name: 'toplamdan fazla → biter', totalUnits: 100, reached: 130, expected: true },
  ]

  it.each(cases)('$name', ({ totalUnits, reached, expected }) => {
    const latest = reached === undefined ? undefined : entry({ reachedUnit: reached })
    expect(isBookCompleted(book({ totalUnits }), latest)).toBe(expected)
  })
})

describe('bookStatus', () => {
  const archivedAt = daysAgo(1)
  const cases: {
    name: string
    book: Partial<Book>
    reached: number | undefined
    expected: string
  }[] = [
    { name: 'kayıt yok → notStarted', book: {}, reached: undefined, expected: 'notStarted' },
    { name: 'konum 0 → notStarted', book: {}, reached: 0, expected: 'notStarted' },
    { name: 'konum negatif → notStarted', book: {}, reached: -3, expected: 'notStarted' },
    { name: 'ilerleme var → inProgress', book: {}, reached: 10, expected: 'inProgress' },
    {
      name: 'toplam bilinmiyor, ilerleme var → inProgress (asla completed değil)',
      book: { totalUnits: null },
      reached: 500,
      expected: 'inProgress',
    },
    { name: 'toplama ulaştı → completed', book: {}, reached: 100, expected: 'completed' },
    { name: 'toplamı aştı → completed', book: {}, reached: 120, expected: 'completed' },
    {
      name: 'arşivli, bitmemiş → archived',
      book: { archivedAt },
      reached: 10,
      expected: 'archived',
    },
    {
      name: 'arşivli, kayıt yok → archived (notStarted’tan önce)',
      book: { archivedAt },
      reached: undefined,
      expected: 'archived',
    },
    {
      name: 'arşivli ve bitmiş → completed arşivlinin önüne geçer',
      book: { archivedAt },
      reached: 100,
      expected: 'completed',
    },
  ]

  it.each(cases)('$name', ({ book: overrides, reached, expected }) => {
    const latest = reached === undefined ? undefined : entry({ reachedUnit: reached })
    expect(bookStatus(book(overrides), latest)).toBe(expected)
  })
})

describe('weeklyPace', () => {
  const cases: { name: string; entries: BookProgress[]; expected: number | null }[] = [
    { name: 'boş geçmiş → null', entries: [], expected: null },
    { name: 'pencere içinde tek kayıt → null', entries: [at_(2, 40)], expected: null },
    {
      name: 'yalnızca silinmiş kayıtlar → null',
      entries: [at_(2, 40, { deletedAt: daysAgo(1) }), at_(3, 10, { deletedAt: daysAgo(1) })],
      expected: null,
    },
    {
      name: 'yalnızca gelecek tarihli kayıt → null',
      entries: [entry({ recordedAt: at(DAY_MS), reachedUnit: 50 })],
      expected: null,
    },
    {
      name: 'pencere öncesi kayıt + pencere içi kayıt → fark',
      entries: [at_(10, 50), at_(2, 80)],
      expected: 30,
    },
    {
      name: 'pencere öncesi baseline: en son (pencereye en yakın) olan seçilir',
      entries: [at_(20, 10), at_(9, 40), at_(2, 70)],
      expected: 30,
    },
    {
      name: 'pencere öncesi tek kayıt, pencerede kayıt yok → 0 (durmuş)',
      entries: [at_(10, 50)],
      expected: 0,
    },
    {
      name: 'pencere öncesi birden fazla kayıt, pencerede yok → 0',
      entries: [at_(20, 10), at_(10, 50)],
      expected: 0,
    },
    {
      name: 'tam now−7g kayıt baseline sayılır (pencere öncesi)',
      entries: [entry({ recordedAt: at(-WINDOW_MS), reachedUnit: 10 }), at_(3, 20)],
      expected: 10,
    },
    {
      name: 'tam now−7g tek kayıt: baseline = bitiş → 0',
      entries: [entry({ recordedAt: at(-WINDOW_MS), reachedUnit: 10 })],
      expected: 0,
    },
    {
      name: 'now−7g−1ms kayıt baseline sayılır',
      entries: [entry({ recordedAt: at(-WINDOW_MS - 1), reachedUnit: 10 }), at_(3, 25)],
      expected: 15,
    },
    {
      name: 'now−7g+1ms kayıt pencere içidir: tek kayıt → null',
      entries: [entry({ recordedAt: at(-WINDOW_MS + 1), reachedUnit: 10 })],
      expected: null,
    },
    {
      name: 'öncesi yoksa pencere içindeki en eski kayıt baseline',
      entries: [at_(5, 20), at_(3, 35), at_(1, 50)],
      expected: 30,
    },
    {
      name: 'geri giden ilerleme negatif hız üretmez',
      entries: [at_(10, 100), at_(1, 80)],
      expected: 0,
    },
    {
      name: 'geri giden ilerleme (pencere içi) negatif hız üretmez',
      entries: [at_(5, 90), at_(1, 40)],
      expected: 0,
    },
    {
      name: 'gelecek tarihli kayıt bitiş noktası olmaz',
      entries: [at_(10, 50), entry({ recordedAt: at(DAY_MS), reachedUnit: 500 }), at_(1, 70)],
      expected: 20,
    },
    {
      name: 'tam now anındaki kayıt bitiş noktası sayılır',
      entries: [at_(3, 10), entry({ recordedAt: NOW.toISOString(), reachedUnit: 30 })],
      expected: 20,
    },
    {
      name: 'silinmiş kayıtlar baseline/bitiş olmaz',
      entries: [at_(10, 50), at_(2, 60), at_(1, 500, { deletedAt: daysAgo(0) })],
      expected: 10,
    },
    {
      name: 'recordedAt eşitliğinde createdAt’i yeni olan bitiş noktasıdır',
      entries: [
        at_(3, 10),
        at_(1, 30, { createdAt: at(-2000) }),
        at_(1, 40, { createdAt: at(-1000) }),
      ],
      expected: 30,
    },
    {
      name: 'ondalıklı birimler korunur',
      entries: [at_(10, 1.5), at_(1, 4)],
      expected: 2.5,
    },
  ]

  it.each(cases)('$name', ({ entries, expected }) => {
    expect(weeklyPace(entries, NOW)).toBe(expected)
  })

  it('girdi dizisini mutasyona uğratmaz', () => {
    const input = Object.freeze([at_(1, 70), at_(10, 50), at_(3, 60)])
    const snapshot = [...input]
    expect(weeklyPace(input, NOW)).toBe(20)
    expect([...input]).toEqual(snapshot)
  })

  it('PACE_WINDOW_DAYS 7’dir', () => {
    expect(PACE_WINDOW_DAYS).toBe(7)
  })
})

describe('estimateDaysToFinish', () => {
  const cases: {
    name: string
    totalUnits: number | null
    reached: number | undefined
    pace: number | null
    expected: number | null
  }[] = [
    { name: 'toplam null → null', totalUnits: null, reached: 10, pace: 14, expected: null },
    { name: 'toplam 0 → null', totalUnits: 0, reached: 0, pace: 14, expected: null },
    { name: 'toplam negatif → null', totalUnits: -5, reached: 0, pace: 14, expected: null },
    { name: 'toplam NaN → null', totalUnits: Number.NaN, reached: 0, pace: 14, expected: null },
    {
      name: 'toplam Infinity → null',
      totalUnits: Number.POSITIVE_INFINITY,
      reached: 0,
      pace: 14,
      expected: null,
    },
    {
      name: 'tam bitti → 0 (hız null olsa da)',
      totalUnits: 100,
      reached: 100,
      pace: null,
      expected: 0,
    },
    { name: 'toplamı aştı → 0', totalUnits: 100, reached: 130, pace: 0, expected: 0 },
    { name: 'hız null → null', totalUnits: 100, reached: 70, pace: null, expected: null },
    { name: 'hız 0 → null', totalUnits: 100, reached: 70, pace: 0, expected: null },
    { name: 'hız negatif → null', totalUnits: 100, reached: 70, pace: -4, expected: null },
    { name: 'tam bölünür: 30 / (7/7)', totalUnits: 100, reached: 70, pace: 7, expected: 30 },
    {
      name: 'yukarı yuvarlanır: 30 / (20/7) = 10.5 → 11',
      totalUnits: 100,
      reached: 70,
      pace: 20,
      expected: 11,
    },
    { name: 'tam gün: 30 / (10/7) = 21', totalUnits: 100, reached: 70, pace: 10, expected: 21 },
    { name: 'çok küçük kalan bile 1 gün', totalUnits: 100, reached: 99, pace: 700, expected: 1 },
    {
      name: 'kayıt yoksa konum 0 sayılır',
      totalUnits: 100,
      reached: undefined,
      pace: 14,
      expected: 50,
    },
  ]

  it.each(cases)('$name', ({ totalUnits, reached, pace, expected }) => {
    const latest = reached === undefined ? undefined : entry({ reachedUnit: reached })
    expect(estimateDaysToFinish(book({ totalUnits }), latest, pace)).toBe(expected)
  })
})

describe('summarizeBook', () => {
  it('geçmişi boş kitap: varsayılan değerler', () => {
    const b = book({ updatedAt: daysAgo(4), totalUnits: 100 })

    const s = summarizeBook(b, [], NOW)

    expect(s).toEqual({
      book: b,
      latest: undefined,
      reachedUnit: 0,
      ratio: 0,
      status: 'notStarted',
      lastProgressAt: null,
      weeklyPace: null,
      daysToFinish: null,
      activityAt: b.updatedAt,
    })
  })

  it('toplamı bilinmeyen kitap: ratio ve daysToFinish null, status inProgress', () => {
    const b = book({ totalUnits: null })
    const s = summarizeBook(b, [at_(10, 20), at_(1, 50)], NOW)

    expect(s.ratio).toBeNull()
    expect(s.daysToFinish).toBeNull()
    expect(s.status).toBe('inProgress')
    expect(s.weeklyPace).toBe(30)
  })

  it('tüm alanları birlikte hesaplar', () => {
    const b = book({ totalUnits: 100, updatedAt: daysAgo(30) })
    const older = at_(10, 40)
    const latest = at_(1, 70)

    const s = summarizeBook(b, [older, latest], NOW)

    expect(s.latest).toBe(latest)
    expect(s.reachedUnit).toBe(70)
    expect(s.ratio).toBe(0.7)
    expect(s.status).toBe('inProgress')
    expect(s.lastProgressAt).toBe(latest.recordedAt)
    expect(s.weeklyPace).toBe(30)
    expect(s.daysToFinish).toBe(7) // 30 kalan / (30/7 per gün) = 7
    expect(s.activityAt).toBe(latest.recordedAt)
  })

  it('toplamı aşan konum: ratio 1, completed, daysToFinish 0', () => {
    const s = summarizeBook(book({ totalUnits: 100 }), [at_(1, 150)], NOW)

    expect(s.ratio).toBe(1)
    expect(s.status).toBe('completed')
    expect(s.daysToFinish).toBe(0)
  })

  it('activityAt: book.updatedAt daha yeniyse onu kullanır', () => {
    const b = book({ updatedAt: daysAgo(1) })
    const s = summarizeBook(b, [at_(5, 10)], NOW)
    expect(s.activityAt).toBe(b.updatedAt)
  })

  it('activityAt: son ilerleme daha yeniyse onu kullanır', () => {
    const b = book({ updatedAt: daysAgo(9) })
    const latest = at_(2, 10)
    const s = summarizeBook(b, [latest], NOW)
    expect(s.activityAt).toBe(latest.recordedAt)
  })

  it('activityAt: eşitse ikisi de aynı değeri verir', () => {
    const b = book({ updatedAt: daysAgo(2) })
    const s = summarizeBook(b, [at_(2, 10)], NOW)
    expect(s.activityAt).toBe(daysAgo(2))
  })

  it('silinmiş kayıtlar yok sayılır', () => {
    const live = at_(3, 20)
    const deleted = at_(1, 90, { deletedAt: daysAgo(0) })
    const s = summarizeBook(book({ updatedAt: daysAgo(30) }), [live, deleted], NOW)

    expect(s.latest).toBe(live)
    expect(s.reachedUnit).toBe(20)
    expect(s.activityAt).toBe(live.recordedAt)
  })

  it('gelecek tarihli kayıt latest/activityAt’i etkiler ama hıza girmez', () => {
    const past = at_(10, 50)
    const mid = at_(1, 60)
    const future = entry({ recordedAt: at(2 * DAY_MS), reachedUnit: 90 })

    const s = summarizeBook(book({ updatedAt: daysAgo(30) }), [past, mid, future], NOW)

    expect(s.latest).toBe(future)
    expect(s.reachedUnit).toBe(90)
    expect(s.activityAt).toBe(future.recordedAt)
    expect(s.weeklyPace).toBe(10)
  })

  it('girdileri mutasyona uğratmaz', () => {
    const b = Object.freeze(book())
    const entries = Object.freeze([at_(5, 10), at_(1, 30)])
    expect(() => summarizeBook(b, entries, NOW)).not.toThrow()
  })
})

describe('summarizeBooks', () => {
  it('boş girdi → boş liste', () => {
    expect(summarizeBooks([], [], NOW)).toEqual([])
  })

  it('silinmiş kitapları atar, kayıtsız kitabı tutar', () => {
    const live = book({ title: 'Canlı' })
    const gone = book({ title: 'Silinmiş', deletedAt: daysAgo(1) })

    const result = summarizeBooks([live, gone], [], NOW)

    expect(result.map((s) => s.book.id)).toEqual([live.id])
  })

  it('eşleşmeyen (yetim) ve başka kitaba ait kayıtları yok sayar', () => {
    const a = book({ title: 'A' })
    const b = book({ title: 'B' })
    const forA = entry({ bookId: a.id, reachedUnit: 30, recordedAt: daysAgo(2) })
    const forB = entry({ bookId: b.id, reachedUnit: 60, recordedAt: daysAgo(3) })
    const orphan = entry({ bookId: 'yok-boyle-kitap', reachedUnit: 99, recordedAt: daysAgo(0) })

    const result = summarizeBooks([a, b], [forA, forB, orphan], NOW)
    const byId = new Map(result.map((s) => [s.book.id, s]))

    expect(byId.get(a.id)?.reachedUnit).toBe(30)
    expect(byId.get(b.id)?.reachedUnit).toBe(60)
    expect(result).toHaveLength(2)
  })

  it('silinmiş kitabın kayıtları başka kitaplara sızmaz', () => {
    const live = book()
    const gone = book({ deletedAt: daysAgo(1) })
    const goneEntry = entry({ bookId: gone.id, reachedUnit: 50, recordedAt: daysAgo(1) })

    const result = summarizeBooks([live, gone], [goneEntry], NOW)

    expect(result).toHaveLength(1)
    expect(result[0]?.latest).toBeUndefined()
  })

  it('silinmiş ilerleme kayıtları sayılmaz', () => {
    const b = book()
    const e = entry({
      bookId: b.id,
      reachedUnit: 50,
      recordedAt: daysAgo(1),
      deletedAt: daysAgo(0),
    })
    const [s] = summarizeBooks([b], [e], NOW)
    expect(s?.status).toBe('notStarted')
    expect(s?.lastProgressAt).toBeNull()
  })

  it('activityAt’e göre yeni → eski sıralar', () => {
    const old = book({ title: 'Eski', updatedAt: daysAgo(20) })
    const mid = book({ title: 'Orta', updatedAt: daysAgo(10) })
    const fresh = book({ title: 'Yeni', updatedAt: daysAgo(30) })
    // "Yeni" kitabın son ilerlemesi en taze → en üste çıkar.
    const freshEntry = entry({ bookId: fresh.id, reachedUnit: 5, recordedAt: daysAgo(1) })

    const result = summarizeBooks([old, mid, fresh], [freshEntry], NOW)

    expect(result.map((s) => s.book.title)).toEqual(['Yeni', 'Orta', 'Eski'])
  })

  it('eşit activityAt’te başlığa göre tr-TR alfabetik', () => {
    const same = daysAgo(2)
    const titles = ['Zeka', 'İpek', 'ışık', 'Cebir', 'Çözüm']
    const books = titles.map((title) => book({ title, updatedAt: same }))

    const result = summarizeBooks(books, [], NOW)

    // tr-TR: c < ç < ı < i < İ... ('ışık' < 'İpek'), z sonda
    expect(result.map((s) => s.book.title)).toEqual(['Cebir', 'Çözüm', 'ışık', 'İpek', 'Zeka'])
  })

  it('girdi dizilerini mutasyona uğratmaz', () => {
    const a = book({ title: 'A', updatedAt: daysAgo(5) })
    const b = book({ title: 'B', updatedAt: daysAgo(1) })
    const books = Object.freeze([a, b])
    const progress = Object.freeze([
      entry({ bookId: a.id, reachedUnit: 1, recordedAt: daysAgo(2) }),
    ])

    const result = summarizeBooks(books, progress, NOW)

    expect(result.map((s) => s.book.id)).toEqual([b.id, a.id])
    expect([...books]).toEqual([a, b])
  })
})

describe('isFinished / splitByFinished', () => {
  function summaryWithStatus(status: 'notStarted' | 'inProgress' | 'completed' | 'archived') {
    const archivedAt = status === 'archived' ? daysAgo(1) : null
    const reached = { notStarted: 0, inProgress: 10, completed: 100, archived: 10 }[status]
    const b = book({ archivedAt, title: status })
    return summarizeBook(b, reached > 0 ? [at_(1, reached)] : [], NOW)
  }

  it.each([
    ['notStarted', false],
    ['inProgress', false],
    ['completed', true],
    ['archived', true],
  ] as const)('isFinished(%s) = %s', (status, expected) => {
    expect(isFinished(summaryWithStatus(status))).toBe(expected)
  })

  it('boş girdi → iki boş liste', () => {
    expect(splitByFinished([])).toEqual({ active: [], finished: [] })
  })

  it('devam edenleri ve bitenleri ayırır, girdi sırasını korur', () => {
    const s1 = summaryWithStatus('inProgress')
    const s2 = summaryWithStatus('completed')
    const s3 = summaryWithStatus('notStarted')
    const s4 = summaryWithStatus('archived')
    const input = Object.freeze([s1, s2, s3, s4])

    const { active, finished } = splitByFinished(input)

    expect(active).toEqual([s1, s3])
    expect(finished).toEqual([s2, s4])
  })
})

describe('groupBySubject', () => {
  const SUBJECT_A = 'subject-a'
  const SUBJECT_B = 'subject-b'

  function summary(title: string, subjectId: string | null, updatedDaysAgo: number) {
    return summarizeBook(book({ title, subjectId, updatedAt: daysAgo(updatedDaysAgo) }), [], NOW)
  }

  it('boş girdi → boş liste', () => {
    expect(groupBySubject([])).toEqual([])
  })

  it('dersleri en yeni etkinliğe göre sıralar; dersi olmayan grup her zaman sonda', () => {
    const none1 = summary('Dersiz-1', null, 0) // en taze ama null grubu sonda
    const a1 = summary('A-1', SUBJECT_A, 5)
    const a2 = summary('A-2', SUBJECT_A, 9)
    const b1 = summary('B-1', SUBJECT_B, 2)
    const none2 = summary('Dersiz-2', null, 7)

    const groups = groupBySubject([none1, a1, a2, b1, none2])

    expect(groups.map((g) => g.subjectId)).toEqual([SUBJECT_B, SUBJECT_A, null])
  })

  it('grup içi sıra activityAt yeni → eski', () => {
    const a1 = summary('A-eski', SUBJECT_A, 9)
    const a2 = summary('A-yeni', SUBJECT_A, 1)
    const a3 = summary('A-orta', SUBJECT_A, 5)
    const n1 = summary('N-eski', null, 8)
    const n2 = summary('N-yeni', null, 3)

    const groups = groupBySubject([a1, n1, a2, n2, a3])

    expect(groups).toHaveLength(2)
    expect(groups[0]?.books.map((s) => s.book.title)).toEqual(['A-yeni', 'A-orta', 'A-eski'])
    expect(groups[1]?.subjectId).toBeNull()
    expect(groups[1]?.books.map((s) => s.book.title)).toEqual(['N-yeni', 'N-eski'])
  })

  it('yalnızca dersi olmayan kitaplar → tek null grup', () => {
    const groups = groupBySubject([summary('X', null, 1), summary('Y', null, 2)])
    expect(groups.map((g) => g.subjectId)).toEqual([null])
    expect(groups[0]?.books).toHaveLength(2)
  })

  it('eşit activityAt’te başlık tr-TR sırası uygulanır', () => {
    const z = summary('Zeka', SUBJECT_A, 3)
    const c = summary('Cebir', SUBJECT_A, 3)
    const groups = groupBySubject([z, c])
    expect(groups[0]?.books.map((s) => s.book.title)).toEqual(['Cebir', 'Zeka'])
  })

  it('girdi dizisini mutasyona uğratmaz', () => {
    const first = summary('Eski', SUBJECT_A, 9)
    const second = summary('Yeni', SUBJECT_A, 1)
    const input = Object.freeze([first, second])

    const groups = groupBySubject(input)

    expect(groups[0]?.books.map((s) => s.book.title)).toEqual(['Yeni', 'Eski'])
    expect([...input]).toEqual([first, second])
  })
})
