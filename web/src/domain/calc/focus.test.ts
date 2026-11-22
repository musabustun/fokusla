/**
 * Odak hesapları testleri. Vakalar düz veridir (ISO dizge girer, sayı/ISO dizge çıkar) —
 * Swift XCTest port'unda aynen tekrar kullanılacak. Saat dilimine bağlı vakalar
 * `process.env.TZ` ile sabitlenir ve her blok sonunda eski değer geri yüklenir.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import type { FocusSegment, FocusSegmentKind, FocusSession, ISODate } from '../types'
import {
  computeSessionStats,
  currentSegmentElapsedMs,
  dailyFocusTotalMs,
  dailyFocusTotals,
  findOpenSegment,
  getFocusPhase,
  isLongBreak,
  LONG_BREAK_THRESHOLD_MS,
  localDayBounds,
  openSegmentDurationMs,
  recentDays,
  RECENT_DAYS_COUNT,
  segmentDurationMs,
} from './focus'

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

const MIN = 60 * 1000
const HOUR = 60 * MIN

const FIXED = '2026-01-01T00:00:00.000Z'
const SESSION_ID = 'session-1'
const DELETED_AT = '2026-11-19T12:00:00.000Z'

interface SegmentSpec {
  kind?: FocusSegmentKind
  startedAt: string
  endedAt: string | null
  sessionId?: string
  deletedAt?: string | null
  id?: string
}

let segmentSeq = 0
function seg(spec: SegmentSpec): FocusSegment {
  segmentSeq += 1
  return {
    id: spec.id ?? `segment-${segmentSeq}`,
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: spec.deletedAt ?? null,
    sessionId: spec.sessionId ?? SESSION_ID,
    kind: spec.kind ?? 'focus',
    startedAt: spec.startedAt,
    endedAt: spec.endedAt,
  }
}

interface SessionSpec {
  id?: string
  startedAt?: string
  endedAt?: string | null
  deletedAt?: string | null
}

function session(spec: SessionSpec = {}): FocusSession {
  return {
    id: spec.id ?? SESSION_ID,
    createdAt: FIXED,
    updatedAt: FIXED,
    deletedAt: spec.deletedAt ?? null,
    subjectId: null,
    topicId: null,
    startedAt: spec.startedAt ?? '2026-11-19T07:00:00.000Z',
    endedAt: spec.endedAt ?? null,
    note: null,
  }
}

interface ProcessLike {
  process: { env: Record<string, string | undefined> }
}
const env = (globalThis as unknown as ProcessLike).process.env

/** Bloğun testleri boyunca yerel saat dilimini sabitler; sonunda eskisini geri yükler. */
function useTimeZone(timeZone: string): void {
  let original: string | undefined
  beforeAll(() => {
    original = env.TZ
    env.TZ = timeZone
  })
  afterAll(() => {
    if (original === undefined) delete env.TZ
    else env.TZ = original
  })
}

const at = (iso: string) => new Date(iso)

// ---------------------------------------------------------------------------
// Saat diliminden bağımsız fonksiyonlar (UTC'de çalıştırılır)
// ---------------------------------------------------------------------------

describe('UTC', () => {
  useTimeZone('UTC')

  describe('segmentDurationMs', () => {
    it.each<{ name: string; segment: SegmentSpec; now: string; expected: number }>([
      {
        name: 'kapanmış segment: endedAt − startedAt',
        segment: { startedAt: '2026-11-19T10:00:00.000Z', endedAt: '2026-11-19T10:25:00.000Z' },
        now: '2026-11-19T12:00:00.000Z',
        expected: 25 * MIN,
      },
      {
        name: 'açık segment now anında kapanmış sayılır',
        segment: { startedAt: '2026-11-19T10:00:00.000Z', endedAt: null },
        now: '2026-11-19T10:12:30.000Z',
        expected: 12 * MIN + 30_000,
      },
      {
        name: 'açık segment, now < startedAt → 0',
        segment: { startedAt: '2026-11-19T10:00:00.000Z', endedAt: null },
        now: '2026-11-19T09:59:00.000Z',
        expected: 0,
      },
      {
        name: 'endedAt < startedAt (saat kayması) → 0',
        segment: { startedAt: '2026-11-19T10:00:00.000Z', endedAt: '2026-11-19T09:00:00.000Z' },
        now: '2026-11-19T12:00:00.000Z',
        expected: 0,
      },
      {
        name: 'sıfır uzunlukta segment → 0',
        segment: { startedAt: '2026-11-19T10:00:00.000Z', endedAt: '2026-11-19T10:00:00.000Z' },
        now: '2026-11-19T12:00:00.000Z',
        expected: 0,
      },
      {
        name: 'geçersiz zaman damgası → 0',
        segment: { startedAt: 'bozuk', endedAt: '2026-11-19T10:00:00.000Z' },
        now: '2026-11-19T12:00:00.000Z',
        expected: 0,
      },
      {
        name: 'silinmiş segment yok sayılır → 0',
        segment: {
          startedAt: '2026-11-19T10:00:00.000Z',
          endedAt: '2026-11-19T10:25:00.000Z',
          deletedAt: DELETED_AT,
        },
        now: '2026-11-19T12:00:00.000Z',
        expected: 0,
      },
    ])('$name', ({ segment, now, expected }) => {
      expect(segmentDurationMs(seg(segment), at(now))).toBe(expected)
    })

    it('girdiyi mutasyona uğratmaz', () => {
      const s = Object.freeze(seg({ startedAt: '2026-11-19T10:00:00.000Z', endedAt: null }))
      expect(() => segmentDurationMs(s, at('2026-11-19T10:05:00.000Z'))).not.toThrow()
    })
  })

  describe('computeSessionStats', () => {
    const now = '2026-11-19T12:00:00.000Z'
    const ZERO = {
      focusMs: 0,
      breakMs: 0,
      focusCount: 0,
      breakCount: 0,
      averageFocusMs: 0,
      averageBreakMs: 0,
    }

    it.each<{ name: string; segments: SegmentSpec[]; expected: typeof ZERO }>([
      { name: 'boş liste → tüm değerler 0', segments: [], expected: ZERO },
      {
        name: 'kapanmış odak + mola: toplamlar, sayılar ve ortalamalar',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:25:00.000Z',
          },
          {
            kind: 'break',
            startedAt: '2026-11-19T09:25:00.000Z',
            endedAt: '2026-11-19T09:30:00.000Z',
          },
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:30:00.000Z',
            endedAt: '2026-11-19T10:05:00.000Z',
          },
        ],
        expected: {
          focusMs: 60 * MIN,
          breakMs: 5 * MIN,
          focusCount: 2,
          breakCount: 1,
          averageFocusMs: 30 * MIN,
          averageBreakMs: 5 * MIN,
        },
      },
      {
        name: 'sıra önemsiz (ters sıralı girdi aynı sonucu verir)',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:30:00.000Z',
            endedAt: '2026-11-19T10:05:00.000Z',
          },
          {
            kind: 'break',
            startedAt: '2026-11-19T09:25:00.000Z',
            endedAt: '2026-11-19T09:30:00.000Z',
          },
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:25:00.000Z',
          },
        ],
        expected: {
          focusMs: 60 * MIN,
          breakMs: 5 * MIN,
          focusCount: 2,
          breakCount: 1,
          averageFocusMs: 30 * MIN,
          averageBreakMs: 5 * MIN,
        },
      },
      {
        name: 'açık odak segmenti toplama now’a kadar girer, ortalamaya girmez',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T11:00:00.000Z',
            endedAt: '2026-11-19T11:20:00.000Z',
          },
          {
            kind: 'break',
            startedAt: '2026-11-19T11:20:00.000Z',
            endedAt: '2026-11-19T11:30:00.000Z',
          },
          { kind: 'focus', startedAt: '2026-11-19T11:30:00.000Z', endedAt: null },
        ],
        expected: {
          focusMs: 50 * MIN,
          breakMs: 10 * MIN,
          focusCount: 2,
          breakCount: 1,
          averageFocusMs: 20 * MIN,
          averageBreakMs: 10 * MIN,
        },
      },
      {
        name: 'yalnızca açık odak segmenti → ortalama 0, sayı 1',
        segments: [{ kind: 'focus', startedAt: '2026-11-19T11:45:00.000Z', endedAt: null }],
        expected: { ...ZERO, focusMs: 15 * MIN, focusCount: 1 },
      },
      {
        name: 'açık mola segmenti toplama girer, mola ortalamasına girmez',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T11:00:00.000Z',
            endedAt: '2026-11-19T11:40:00.000Z',
          },
          { kind: 'break', startedAt: '2026-11-19T11:40:00.000Z', endedAt: null },
        ],
        expected: {
          focusMs: 40 * MIN,
          breakMs: 20 * MIN,
          focusCount: 1,
          breakCount: 1,
          averageFocusMs: 40 * MIN,
          averageBreakMs: 0,
        },
      },
      {
        name: 'silinmiş segmentler yok sayılır',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:30:00.000Z',
          },
          {
            kind: 'focus',
            startedAt: '2026-11-19T10:00:00.000Z',
            endedAt: '2026-11-19T11:00:00.000Z',
            deletedAt: DELETED_AT,
          },
          {
            kind: 'break',
            startedAt: '2026-11-19T09:30:00.000Z',
            endedAt: null,
            deletedAt: DELETED_AT,
          },
        ],
        expected: { ...ZERO, focusMs: 30 * MIN, focusCount: 1, averageFocusMs: 30 * MIN },
      },
      {
        name: 'endedAt < startedAt olan kapanmış segment 0 sayılır',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:40:00.000Z',
          },
          {
            kind: 'focus',
            startedAt: '2026-11-19T10:00:00.000Z',
            endedAt: '2026-11-19T09:00:00.000Z',
          },
        ],
        expected: { ...ZERO, focusMs: 40 * MIN, focusCount: 2, averageFocusMs: 20 * MIN },
      },
    ])('$name', ({ segments, expected }) => {
      expect(computeSessionStats(segments.map(seg), at(now))).toEqual(expected)
    })
  })

  describe('findOpenSegment', () => {
    it.each<{ name: string; segments: SegmentSpec[]; expectedId: string | undefined }>([
      { name: 'boş liste → undefined', segments: [], expectedId: undefined },
      {
        name: 'tümü kapalı → undefined',
        segments: [
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: '2026-11-19T09:25:00.000Z' },
        ],
        expectedId: undefined,
      },
      {
        name: 'tek açık segment',
        segments: [
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: '2026-11-19T09:25:00.000Z' },
          { id: 'b', kind: 'break', startedAt: '2026-11-19T09:25:00.000Z', endedAt: null },
        ],
        expectedId: 'b',
      },
      {
        name: 'birden fazla açık → en son başlayan (sonda)',
        segments: [
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: null },
          { id: 'b', startedAt: '2026-11-19T10:00:00.000Z', endedAt: null },
        ],
        expectedId: 'b',
      },
      {
        name: 'birden fazla açık → en son başlayan (başta)',
        segments: [
          { id: 'b', startedAt: '2026-11-19T10:00:00.000Z', endedAt: null },
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: null },
        ],
        expectedId: 'b',
      },
      {
        name: 'silinmiş açık segment yok sayılır',
        segments: [
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: null },
          { id: 'b', startedAt: '2026-11-19T10:00:00.000Z', endedAt: null, deletedAt: DELETED_AT },
        ],
        expectedId: 'a',
      },
      {
        name: 'yalnızca silinmiş açık segment → undefined',
        segments: [
          { id: 'a', startedAt: '2026-11-19T09:00:00.000Z', endedAt: null, deletedAt: DELETED_AT },
        ],
        expectedId: undefined,
      },
    ])('$name', ({ segments, expectedId }) => {
      expect(findOpenSegment(segments.map(seg))?.id).toBe(expectedId)
    })
  })

  describe('getFocusPhase', () => {
    it.each<{
      name: string
      session: SessionSpec
      segments: SegmentSpec[]
      expected: 'focus' | 'break' | 'ended'
    }>([
      {
        name: 'bitmiş oturum → ended (açık segment kalmış olsa bile)',
        session: { endedAt: '2026-11-19T10:00:00.000Z' },
        segments: [{ startedAt: '2026-11-19T09:00:00.000Z', endedAt: null }],
        expected: 'ended',
      },
      {
        name: 'açık odak segmenti → focus',
        session: {},
        segments: [
          {
            kind: 'break',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:05:00.000Z',
          },
          { kind: 'focus', startedAt: '2026-11-19T09:05:00.000Z', endedAt: null },
        ],
        expected: 'focus',
      },
      {
        name: 'açık mola segmenti → break',
        session: {},
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:25:00.000Z',
          },
          { kind: 'break', startedAt: '2026-11-19T09:25:00.000Z', endedAt: null },
        ],
        expected: 'break',
      },
      {
        name: 'aktif oturumda açık segment yok (tutarsız veri) → break',
        session: {},
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:25:00.000Z',
          },
        ],
        expected: 'break',
      },
      {
        name: 'aktif oturum, hiç segment yok → break',
        session: {},
        segments: [],
        expected: 'break',
      },
      {
        name: 'başka oturumun açık segmenti yok sayılır → break',
        session: {},
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: null,
            sessionId: 'other',
          },
        ],
        expected: 'break',
      },
      {
        name: 'silinmiş oturum → ended',
        session: { deletedAt: DELETED_AT },
        segments: [{ kind: 'focus', startedAt: '2026-11-19T09:00:00.000Z', endedAt: null }],
        expected: 'ended',
      },
    ])('$name', ({ session: s, segments, expected }) => {
      expect(getFocusPhase(session(s), segments.map(seg))).toBe(expected)
    })
  })

  describe('openSegmentDurationMs', () => {
    const now = '2026-11-19T10:00:00.000Z'
    it.each<{ name: string; segments: SegmentSpec[]; kind: FocusSegmentKind; expected: number }>([
      { name: 'boş liste → 0', segments: [], kind: 'focus', expected: 0 },
      {
        name: 'açık odak, tür focus → now’a kadarki süre',
        segments: [{ kind: 'focus', startedAt: '2026-11-19T09:20:00.000Z', endedAt: null }],
        kind: 'focus',
        expected: 40 * MIN,
      },
      {
        name: 'açık odak, tür break → 0',
        segments: [{ kind: 'focus', startedAt: '2026-11-19T09:20:00.000Z', endedAt: null }],
        kind: 'break',
        expected: 0,
      },
      {
        name: 'açık mola, tür break → now’a kadarki süre',
        segments: [{ kind: 'break', startedAt: '2026-11-19T09:50:00.000Z', endedAt: null }],
        kind: 'break',
        expected: 10 * MIN,
      },
      {
        name: 'yalnızca kapalı segmentler → 0',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:30:00.000Z',
          },
        ],
        kind: 'focus',
        expected: 0,
      },
    ])('$name', ({ segments, kind, expected }) => {
      expect(openSegmentDurationMs(segments.map(seg), kind, at(now))).toBe(expected)
    })
  })

  describe('currentSegmentElapsedMs', () => {
    it.each<{ name: string; segments: SegmentSpec[]; now: string; expected: number }>([
      { name: 'boş liste → 0', segments: [], now: '2026-11-19T10:00:00.000Z', expected: 0 },
      {
        name: 'açık segment yok (yalnızca kapalılar) → 0',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:30:00.000Z',
          },
        ],
        now: '2026-11-19T10:00:00.000Z',
        expected: 0,
      },
      {
        name: 'açık odak: toplam değil, son devamdan beri (kapalı odak sayılmaz)',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T08:00:00.000Z',
            endedAt: '2026-11-19T09:00:00.000Z',
          },
          {
            kind: 'break',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T09:40:00.000Z',
          },
          { kind: 'focus', startedAt: '2026-11-19T09:40:00.000Z', endedAt: null },
        ],
        now: '2026-11-19T10:00:00.000Z',
        expected: 20 * MIN,
      },
      {
        name: 'açık mola: molanın başından beri',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T08:00:00.000Z',
            endedAt: '2026-11-19T09:50:00.000Z',
          },
          { kind: 'break', startedAt: '2026-11-19T09:50:00.000Z', endedAt: null },
        ],
        now: '2026-11-19T10:00:00.000Z',
        expected: 10 * MIN,
      },
      {
        name: 'gece yarısını aşan açık segment bölünmez (23:30 → 00:10 = 40 dk)',
        segments: [{ kind: 'focus', startedAt: '2026-11-19T23:30:00.000Z', endedAt: null }],
        now: '2026-11-20T00:10:00.000Z',
        expected: 40 * MIN,
      },
      {
        name: 'silinmiş açık segment yok sayılır',
        segments: [
          {
            kind: 'focus',
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: null,
            deletedAt: DELETED_AT,
          },
        ],
        now: '2026-11-19T10:00:00.000Z',
        expected: 0,
      },
      {
        name: 'birden fazla açık segment (tutarsız veri): en son başlayan',
        segments: [
          { kind: 'focus', startedAt: '2026-11-19T08:00:00.000Z', endedAt: null },
          { kind: 'break', startedAt: '2026-11-19T09:30:00.000Z', endedAt: null },
        ],
        now: '2026-11-19T10:00:00.000Z',
        expected: 30 * MIN,
      },
      {
        name: 'saat kayması: now < startedAt → 0 (negatif olmaz)',
        segments: [{ kind: 'focus', startedAt: '2026-11-19T10:30:00.000Z', endedAt: null }],
        now: '2026-11-19T10:00:00.000Z',
        expected: 0,
      },
    ])('$name', ({ segments, now, expected }) => {
      expect(currentSegmentElapsedMs(segments.map(seg), at(now))).toBe(expected)
    })
  })

  describe('isLongBreak', () => {
    const start = '2026-11-19T10:00:00.000Z'
    it.each<{
      name: string
      segments: SegmentSpec[]
      now: string
      threshold?: number
      expected: boolean
    }>([
      {
        name: 'segment yok → false',
        segments: [],
        now: '2026-11-19T11:00:00.000Z',
        expected: false,
      },
      {
        name: 'açık mola eşiğin hemen altında (29:59.999) → false',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: '2026-11-19T10:29:59.999Z',
        expected: false,
      },
      {
        name: 'açık mola tam eşikte (30:00) → true',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: '2026-11-19T10:30:00.000Z',
        expected: true,
      },
      {
        name: 'açık mola eşiğin üstünde → true',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: '2026-11-19T11:15:00.000Z',
        expected: true,
      },
      {
        name: 'özel eşik 5 dk, 6 dk mola → true',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: '2026-11-19T10:06:00.000Z',
        threshold: 5 * MIN,
        expected: true,
      },
      {
        name: 'özel eşik 5 dk, 4 dk mola → false',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: '2026-11-19T10:04:00.000Z',
        threshold: 5 * MIN,
        expected: false,
      },
      {
        name: 'özel eşik 0, yeni açılmış mola → true',
        segments: [{ kind: 'break', startedAt: start, endedAt: null }],
        now: start,
        threshold: 0,
        expected: true,
      },
      {
        name: 'açık odak segmenti (2 saat) → false',
        segments: [{ kind: 'focus', startedAt: start, endedAt: null }],
        now: '2026-11-19T12:00:00.000Z',
        expected: false,
      },
      {
        name: 'özel eşik 0, açık mola yok → false',
        segments: [{ kind: 'focus', startedAt: start, endedAt: null }],
        now: '2026-11-19T12:00:00.000Z',
        threshold: 0,
        expected: false,
      },
      {
        name: 'kapanmış uzun mola → false',
        segments: [{ kind: 'break', startedAt: start, endedAt: '2026-11-19T11:30:00.000Z' }],
        now: '2026-11-19T12:00:00.000Z',
        expected: false,
      },
    ])('$name', ({ segments, now, threshold, expected }) => {
      const result =
        threshold === undefined
          ? isLongBreak(segments.map(seg), at(now))
          : isLongBreak(segments.map(seg), at(now), threshold)
      expect(result).toBe(expected)
    })

    it('varsayılan eşik 30 dakikadır', () => {
      expect(LONG_BREAK_THRESHOLD_MS).toBe(30 * MIN)
    })
  })
})

// ---------------------------------------------------------------------------
// Yerel gün hesapları — Europe/Istanbul (UTC+3, DST yok)
// ---------------------------------------------------------------------------

describe('Europe/Istanbul (UTC+3)', () => {
  useTimeZone('Europe/Istanbul')

  describe('localDayBounds', () => {
    it.each<{ day: ISODate; start: string; end: string }>([
      { day: '2026-11-19', start: '2026-11-18T21:00:00.000Z', end: '2026-11-19T21:00:00.000Z' },
      { day: '2026-12-31', start: '2026-12-30T21:00:00.000Z', end: '2026-12-31T21:00:00.000Z' },
      { day: '2028-02-29', start: '2028-02-28T21:00:00.000Z', end: '2028-02-29T21:00:00.000Z' },
    ])('$day → [$start, $end)', ({ day, start, end }) => {
      const bounds = localDayBounds(day)
      expect(bounds.start.toISOString()).toBe(start)
      expect(bounds.end.toISOString()).toBe(end)
    })

    it.each<{ name: string; day: string }>([
      { name: 'ay 13', day: '2026-13-01' },
      { name: 'ay 00', day: '2026-00-10' },
      { name: 'gün 00', day: '2026-01-00' },
      { name: 'olmayan gün (30 Şubat)', day: '2026-02-30' },
      { name: 'artık olmayan yılda 29 Şubat', day: '2026-02-29' },
      { name: 'rastgele metin', day: 'abc' },
      { name: 'boş dizge', day: '' },
      { name: 'sıfırsız biçim', day: '2026-2-3' },
      { name: 'saat içeren dizge', day: '2026-11-19T00:00' },
    ])('geçersiz: $name ($day) → RangeError', ({ day }) => {
      expect(() => localDayBounds(day)).toThrow(RangeError)
    })
  })

  describe('recentDays', () => {
    it.each<{ name: string; now: string; count: number; expected: ISODate[] }>([
      {
        name: 'UTC akşamı yerelde ertesi gündür',
        now: '2026-11-18T22:00:00.000Z',
        count: 2,
        expected: ['2026-11-18', '2026-11-19'],
      },
      {
        name: 'ay sınırını geçer',
        now: '2026-03-01T09:00:00.000Z',
        count: 3,
        expected: ['2026-02-27', '2026-02-28', '2026-03-01'],
      },
      {
        name: 'yıl sınırını geçer',
        now: '2027-01-02T07:00:00.000Z',
        count: 4,
        expected: ['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02'],
      },
      {
        name: 'count 1 → yalnızca bugün',
        now: '2026-11-19T09:00:00.000Z',
        count: 1,
        expected: ['2026-11-19'],
      },
      { name: 'count 0 → boş', now: '2026-11-19T09:00:00.000Z', count: 0, expected: [] },
      { name: 'negatif count → boş', now: '2026-11-19T09:00:00.000Z', count: -3, expected: [] },
    ])('$name', ({ now, count, expected }) => {
      expect(recentDays(at(now), count)).toEqual(expected)
    })

    it('varsayılan 7 gün, eskiden yeniye, son eleman bugün', () => {
      expect(RECENT_DAYS_COUNT).toBe(7)
      expect(recentDays(at('2026-11-19T09:00:00.000Z'))).toEqual([
        '2026-11-13',
        '2026-11-14',
        '2026-11-15',
        '2026-11-16',
        '2026-11-17',
        '2026-11-18',
        '2026-11-19',
      ])
    })
  })

  describe('dailyFocusTotalMs', () => {
    const now = '2026-11-20T09:00:00.000Z'
    it.each<{
      name: string
      sessions: SessionSpec[]
      segments: SegmentSpec[]
      day: ISODate
      now?: string
      expected: number
    }>([
      { name: 'boş listeler → 0', sessions: [], segments: [], day: '2026-11-19', expected: 0 },
      {
        name: 'oturum yok → segmentler sayılmaz',
        sessions: [],
        segments: [{ startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T08:00:00.000Z' }],
        day: '2026-11-19',
        expected: 0,
      },
      {
        name: 'gün içindeki odak segmentleri toplanır',
        sessions: [{}],
        segments: [
          { startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T07:25:00.000Z' },
          { startedAt: '2026-11-19T08:00:00.000Z', endedAt: '2026-11-19T08:35:00.000Z' },
        ],
        day: '2026-11-19',
        expected: 60 * MIN,
      },
      {
        name: 'mola segmentleri sayılmaz',
        sessions: [{}],
        segments: [
          { startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T07:25:00.000Z' },
          {
            kind: 'break',
            startedAt: '2026-11-19T07:25:00.000Z',
            endedAt: '2026-11-19T08:25:00.000Z',
          },
        ],
        day: '2026-11-19',
        expected: 25 * MIN,
      },
      {
        name: 'UTC akşamındaki segment (yerel 01:00–02:00) ertesi yerel güne aittir',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T22:00:00.000Z', endedAt: '2026-11-18T23:00:00.000Z' }],
        day: '2026-11-19',
        expected: HOUR,
      },
      {
        name: 'UTC akşamındaki segment önceki yerel güne sayılmaz',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T22:00:00.000Z', endedAt: '2026-11-18T23:00:00.000Z' }],
        day: '2026-11-18',
        expected: 0,
      },
      {
        name: 'gece yarısını aşan segment: önceki gün payı (23:30–00:00)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T20:30:00.000Z', endedAt: '2026-11-18T21:30:00.000Z' }],
        day: '2026-11-18',
        expected: 30 * MIN,
      },
      {
        name: 'gece yarısını aşan segment: sonraki gün payı (00:00–00:30)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T20:30:00.000Z', endedAt: '2026-11-18T21:30:00.000Z' }],
        day: '2026-11-19',
        expected: 30 * MIN,
      },
      {
        name: 'gece yarısını aşan oturum: her segment kendi gününe',
        sessions: [{ startedAt: '2026-11-18T19:00:00.000Z', endedAt: '2026-11-18T22:30:00.000Z' }],
        segments: [
          { startedAt: '2026-11-18T19:00:00.000Z', endedAt: '2026-11-18T20:00:00.000Z' },
          {
            kind: 'break',
            startedAt: '2026-11-18T20:00:00.000Z',
            endedAt: '2026-11-18T21:30:00.000Z',
          },
          { startedAt: '2026-11-18T21:30:00.000Z', endedAt: '2026-11-18T22:30:00.000Z' },
        ],
        day: '2026-11-19',
        expected: HOUR,
      },
      {
        name: '3 güne yayılan segment: ilk gün (23:00–24:00)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-17T20:00:00.000Z', endedAt: '2026-11-18T22:00:00.000Z' }],
        day: '2026-11-17',
        expected: HOUR,
      },
      {
        name: '3 güne yayılan segment: orta gün tam 24 saat',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-17T20:00:00.000Z', endedAt: '2026-11-18T22:00:00.000Z' }],
        day: '2026-11-18',
        expected: 24 * HOUR,
      },
      {
        name: '3 güne yayılan segment: son gün (00:00–01:00)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-17T20:00:00.000Z', endedAt: '2026-11-18T22:00:00.000Z' }],
        day: '2026-11-19',
        expected: HOUR,
      },
      {
        name: 'açık segment now’a kadar sayılır ve güne kırpılır (önceki gün)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T20:00:00.000Z', endedAt: null }],
        day: '2026-11-18',
        now: '2026-11-19T07:00:00.000Z',
        expected: HOUR,
      },
      {
        name: 'açık segment now’a kadar sayılır ve güne kırpılır (bugün, 00:00–10:00)',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T20:00:00.000Z', endedAt: null }],
        day: '2026-11-19',
        now: '2026-11-19T07:00:00.000Z',
        expected: 10 * HOUR,
      },
      {
        name: 'açık segment gelecek güne taşmaz',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-18T20:00:00.000Z', endedAt: null }],
        day: '2026-11-20',
        now: '2026-11-19T07:00:00.000Z',
        expected: 0,
      },
      {
        name: 'açık segment, now < startedAt → 0',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-19T08:00:00.000Z', endedAt: null }],
        day: '2026-11-19',
        now: '2026-11-19T07:00:00.000Z',
        expected: 0,
      },
      {
        name: 'endedAt < startedAt → 0',
        sessions: [{}],
        segments: [{ startedAt: '2026-11-19T08:00:00.000Z', endedAt: '2026-11-19T07:00:00.000Z' }],
        day: '2026-11-19',
        expected: 0,
      },
      {
        name: 'silinmiş segment sayılmaz',
        sessions: [{}],
        segments: [
          { startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T08:00:00.000Z' },
          {
            startedAt: '2026-11-19T09:00:00.000Z',
            endedAt: '2026-11-19T10:00:00.000Z',
            deletedAt: DELETED_AT,
          },
        ],
        day: '2026-11-19',
        expected: HOUR,
      },
      {
        name: 'silinmiş oturumun segmentleri sayılmaz',
        sessions: [{ deletedAt: DELETED_AT }],
        segments: [{ startedAt: '2026-11-19T07:00:00.000Z', endedAt: '2026-11-19T08:00:00.000Z' }],
        day: '2026-11-19',
        expected: 0,
      },
      {
        name: 'listede olmayan oturumun segmentleri sayılmaz',
        sessions: [{ id: 'a' }],
        segments: [
          {
            sessionId: 'a',
            startedAt: '2026-11-19T07:00:00.000Z',
            endedAt: '2026-11-19T07:30:00.000Z',
          },
          {
            sessionId: 'b',
            startedAt: '2026-11-19T08:00:00.000Z',
            endedAt: '2026-11-19T09:00:00.000Z',
          },
        ],
        day: '2026-11-19',
        expected: 30 * MIN,
      },
      {
        name: 'birden fazla oturumun segmentleri toplanır',
        sessions: [{ id: 'a' }, { id: 'b' }],
        segments: [
          {
            sessionId: 'a',
            startedAt: '2026-11-19T07:00:00.000Z',
            endedAt: '2026-11-19T07:30:00.000Z',
          },
          {
            sessionId: 'b',
            startedAt: '2026-11-19T08:00:00.000Z',
            endedAt: '2026-11-19T09:00:00.000Z',
          },
        ],
        day: '2026-11-19',
        expected: 90 * MIN,
      },
    ])('$name', ({ sessions, segments, day, now: nowOverride, expected }) => {
      const result = dailyFocusTotalMs(
        sessions.map(session),
        segments.map(seg),
        day,
        at(nowOverride ?? now),
      )
      expect(result).toBe(expected)
    })
  })

  describe('dailyFocusTotals', () => {
    const sessions = [session()]
    const segments = [
      seg({ startedAt: '2026-11-17T20:00:00.000Z', endedAt: '2026-11-18T22:00:00.000Z' }),
    ]
    const now = at('2026-11-20T09:00:00.000Z')

    it('boş gün listesi → boş sonuç', () => {
      expect(dailyFocusTotals(sessions, segments, [], now)).toEqual([])
    })

    it('days sırasını korur (sırasız girdi dahil)', () => {
      expect(
        dailyFocusTotals(
          sessions,
          segments,
          ['2026-11-19', '2026-11-16', '2026-11-18', '2026-11-17'],
          now,
        ),
      ).toEqual([
        { day: '2026-11-19', focusMs: HOUR },
        { day: '2026-11-16', focusMs: 0 },
        { day: '2026-11-18', focusMs: 24 * HOUR },
        { day: '2026-11-17', focusMs: HOUR },
      ])
    })

    it('recentDays ile birlikte grafik verisi üretir', () => {
      const days = recentDays(at('2026-11-19T09:00:00.000Z'), 3)
      expect(dailyFocusTotals(sessions, segments, days, now).map((d) => d.focusMs)).toEqual([
        HOUR,
        24 * HOUR,
        HOUR,
      ])
    })

    it('girdileri mutasyona uğratmaz', () => {
      const frozenSessions = Object.freeze([Object.freeze(session())])
      const frozenSegments = Object.freeze(segments.map((s) => Object.freeze({ ...s })))
      const days = Object.freeze(['2026-11-18'])
      expect(dailyFocusTotals(frozenSessions, frozenSegments, days, now)).toEqual([
        { day: '2026-11-18', focusMs: 24 * HOUR },
      ])
    })
  })
})

// ---------------------------------------------------------------------------
// DST — America/New_York (2026-03-08: 23 saat, 2026-11-01: 25 saat)
// ---------------------------------------------------------------------------

describe('America/New_York (DST)', () => {
  useTimeZone('America/New_York')

  describe('localDayBounds', () => {
    it.each<{ name: string; day: ISODate; start: string; end: string; hours: number }>([
      {
        name: 'normal gün (EST) 24 saat',
        day: '2026-01-15',
        start: '2026-01-15T05:00:00.000Z',
        end: '2026-01-16T05:00:00.000Z',
        hours: 24,
      },
      {
        name: 'ileri alma günü 23 saat',
        day: '2026-03-08',
        start: '2026-03-08T05:00:00.000Z',
        end: '2026-03-09T04:00:00.000Z',
        hours: 23,
      },
      {
        name: 'geri alma günü 25 saat',
        day: '2026-11-01',
        start: '2026-11-01T04:00:00.000Z',
        end: '2026-11-02T05:00:00.000Z',
        hours: 25,
      },
    ])('$name ($day)', ({ day, start, end, hours }) => {
      const bounds = localDayBounds(day)
      expect(bounds.start.toISOString()).toBe(start)
      expect(bounds.end.toISOString()).toBe(end)
      expect(bounds.end.getTime() - bounds.start.getTime()).toBe(hours * HOUR)
    })
  })

  describe('recentDays', () => {
    it.each<{ name: string; now: string; count: number; expected: ISODate[] }>([
      {
        name: 'ileri alma gününü atlamaz (now = 9 Mart 00:30 EDT)',
        now: '2026-03-09T04:30:00.000Z',
        count: 3,
        expected: ['2026-03-07', '2026-03-08', '2026-03-09'],
      },
      {
        name: 'geri alma gününü tekrarlamaz (now = 2 Kasım 23:30 EST)',
        now: '2026-11-03T04:30:00.000Z',
        count: 3,
        expected: ['2026-10-31', '2026-11-01', '2026-11-02'],
      },
    ])('$name', ({ now, count, expected }) => {
      expect(recentDays(at(now), count)).toEqual(expected)
    })
  })

  describe('dailyFocusTotals', () => {
    it.each<{ name: string; segment: SegmentSpec; days: ISODate[]; expectedMs: number[] }>([
      {
        name: 'ileri alma günü boyunca süren segment: 1 + 23 + 1 saat',
        // 7 Mart 23:00 EST → 9 Mart 01:00 EDT
        segment: { startedAt: '2026-03-08T04:00:00.000Z', endedAt: '2026-03-09T05:00:00.000Z' },
        days: ['2026-03-07', '2026-03-08', '2026-03-09'],
        expectedMs: [HOUR, 23 * HOUR, HOUR],
      },
      {
        name: 'geri alma günü boyunca süren segment: 1 + 25 + 1 saat',
        // 31 Ekim 23:00 EDT → 2 Kasım 01:00 EST
        segment: { startedAt: '2026-11-01T03:00:00.000Z', endedAt: '2026-11-02T06:00:00.000Z' },
        days: ['2026-10-31', '2026-11-01', '2026-11-02'],
        expectedMs: [HOUR, 25 * HOUR, HOUR],
      },
      {
        name: 'geri alma saatinde (01:00–01:59 iki kez) segment tek güne gerçek süresiyle sayılır',
        // 1 Kasım 00:30 EDT → 01:30 EST (gerçek süre 2 saat)
        segment: { startedAt: '2026-11-01T04:30:00.000Z', endedAt: '2026-11-01T06:30:00.000Z' },
        days: ['2026-10-31', '2026-11-01', '2026-11-02'],
        expectedMs: [0, 2 * HOUR, 0],
      },
    ])('$name', ({ segment, days, expectedMs }) => {
      const totals = dailyFocusTotals(
        [session()],
        [seg(segment)],
        days,
        at('2026-12-01T00:00:00.000Z'),
      )
      expect(totals).toEqual(days.map((day, i) => ({ day, focusMs: expectedMs[i] })))
    })
  })
})
