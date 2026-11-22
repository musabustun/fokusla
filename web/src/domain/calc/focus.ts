/**
 * Odak hesapları — SAF fonksiyonlar (React/Dexie yok). Sahibi: focus feature oturumu.
 *
 * Ortak kurallar (Swift port'u da aynen uygular):
 *  - Birim: milisaniye. Tüm süreler `FocusSegment.startedAt/endedAt` farkından hesaplanır.
 *  - Açık segment (`endedAt === null`) `now` anında kapanmış sayılır.
 *  - Negatif süre üretilmez: `endedAt < startedAt` (saat kayması) ya da `now < startedAt` → 0.
 *  - `deletedAt !== null` olan oturum/segmentler her fonksiyonda yok sayılır.
 *  - Takvim günü (`ISODate`) cihazın GÜNCEL yerel saat diliminde yorumlanır; gece yarısını
 *    aşan segmentler günlere bölünür. Gün sınırları DST'ye dayanıklıdır (23/25 saatlik gün).
 *  - Girdiler mutasyona uğramaz.
 */
import type { FocusSegment, FocusSegmentKind, FocusSession, ISODate } from '../types'
import { toISODate } from '../ids'

/** Bu süreyi aşan molada "Molan uzadı" uyarısı gösterilir (oturum kendiliğinden BİTMEZ). */
export const LONG_BREAK_THRESHOLD_MS = 30 * 60 * 1000

/** Odak ekranındaki günlük grafikte gösterilen gün sayısı. */
export const RECENT_DAYS_COUNT = 7

export interface FocusSessionStats {
  /** Toplam odak süresi (ms); açık odak segmenti `now`'a kadar sayılır. */
  focusMs: number
  /** Toplam mola süresi (ms); açık mola segmenti `now`'a kadar sayılır. */
  breakMs: number
  /** Odak segmenti sayısı (açık olan dahil). */
  focusCount: number
  /** Mola segmenti sayısı (açık olan dahil). */
  breakCount: number
  /**
   * Ortalama kesintisiz odak süresi (ms): YALNIZCA kapanmış odak segmentlerinin ortalaması.
   * Açık segment ortalamayı canlı olarak düşürmesin diye hariçtir. Kapanmış yoksa 0.
   */
  averageFocusMs: number
  /** Ortalama mola süresi (ms): yalnızca kapanmış mola segmentleri. Kapanmış yoksa 0. */
  averageBreakMs: number
}

/** Oturumun anlık durumu. */
export type FocusPhase = 'focus' | 'break' | 'ended'

export interface DailyFocusTotal {
  day: ISODate
  focusMs: number
}

/** ISO tarih-saat dizgesinin epoch milisaniyesi; geçersizse NaN. */
function toMs(iso: string): number {
  return Date.parse(iso)
}

/** Segmentin bitiş anı (ms): kapalıysa `endedAt`, açıksa `now`. */
function segmentEndMs(segment: FocusSegment, now: Date): number {
  return segment.endedAt === null ? now.getTime() : toMs(segment.endedAt)
}

/** [start, end) ile [rangeStart, rangeEnd) kesişiminin uzunluğu; negatif/NaN → 0. */
function overlapMs(start: number, end: number, rangeStart: number, rangeEnd: number): number {
  const length = Math.min(end, rangeEnd) - Math.max(start, rangeStart)
  return length > 0 ? length : 0
}

function isLive<T extends { deletedAt: string | null }>(entity: T): boolean {
  return entity.deletedAt === null
}

/** Bir segmentin süresi (ms). Açık segment için `now` kullanılır. Negatif olmaz. */
export function segmentDurationMs(segment: FocusSegment, now: Date): number {
  if (!isLive(segment)) return 0
  const start = toMs(segment.startedAt)
  return overlapMs(start, segmentEndMs(segment, now), start, Infinity)
}

/** Segmentlerden (bir oturumun ya da tüm geçmişin) istatistik üretir. Sıra önemsizdir. */
export function computeSessionStats(
  segments: readonly FocusSegment[],
  now: Date,
): FocusSessionStats {
  const live = segments.filter(isLive)
  const focus = live.filter((s) => s.kind === 'focus')
  const breaks = live.filter((s) => s.kind === 'break')
  return {
    focusMs: sumDurations(focus, now),
    breakMs: sumDurations(breaks, now),
    focusCount: focus.length,
    breakCount: breaks.length,
    averageFocusMs: averageClosedDuration(focus, now),
    averageBreakMs: averageClosedDuration(breaks, now),
  }
}

function sumDurations(segments: readonly FocusSegment[], now: Date): number {
  return segments.reduce((total, s) => total + segmentDurationMs(s, now), 0)
}

function averageClosedDuration(segments: readonly FocusSegment[], now: Date): number {
  const closed = segments.filter((s) => s.endedAt !== null)
  return closed.length === 0 ? 0 : sumDurations(closed, now) / closed.length
}

/**
 * Açık (endedAt === null) segment; birden fazlaysa (tutarsız veri) en son başlayanı.
 * Yoksa undefined.
 */
export function findOpenSegment(segments: readonly FocusSegment[]): FocusSegment | undefined {
  return segments
    .filter((s) => isLive(s) && s.endedAt === null)
    .reduce<FocusSegment | undefined>(
      (latest, s) =>
        latest === undefined || toMs(s.startedAt) > toMs(latest.startedAt) ? s : latest,
      undefined,
    )
}

/**
 * Oturumun anlık durumu: `session.endedAt` doluysa 'ended'; değilse açık segmentin türü.
 * Açık oturumda açık segment yoksa (tutarsız veri) 'break' döner — sayaç akmaz, kullanıcı
 * "Devam et" ile yeni odak segmenti açabilir.
 * Silinmiş oturum 'ended' sayılır; yalnızca bu oturuma (`sessionId`) ait segmentlere bakılır.
 */
export function getFocusPhase(
  session: FocusSession,
  segments: readonly FocusSegment[],
): FocusPhase {
  if (session.endedAt !== null || !isLive(session)) return 'ended'
  const open = findOpenSegment(segments.filter((s) => s.sessionId === session.id))
  return open?.kind ?? 'break'
}

/** Açık segment verilen türdeyse onun `now`'a kadarki süresi; değilse 0. */
export function openSegmentDurationMs(
  segments: readonly FocusSegment[],
  kind: FocusSegmentKind,
  now: Date,
): number {
  const open = findOpenSegment(segments)
  return open?.kind === kind ? segmentDurationMs(open, now) : 0
}

/**
 * Açık segmentin (odak ya da mola) `now`'a kadarki süresi; açık segment yoksa 0.
 * Ana sayaç "moladan geldiğimden beri" sorusunu cevaplar: odakta SON DEVAMDAN beri geçen süre
 * (oturum toplamı değil), molada molanın süresi. Gece yarısını aşan segment bölünmez.
 */
export function currentSegmentElapsedMs(segments: readonly FocusSegment[], now: Date): number {
  const open = findOpenSegment(segments)
  return open === undefined ? 0 : segmentDurationMs(open, now)
}

/** Açık mola süresi `thresholdMs`'e ulaştı mı (≥: tam eşikte true). Açık mola yoksa false. */
export function isLongBreak(
  segments: readonly FocusSegment[],
  now: Date,
  thresholdMs: number = LONG_BREAK_THRESHOLD_MS,
): boolean {
  if (findOpenSegment(segments)?.kind !== 'break') return false
  return openSegmentDurationMs(segments, 'break', now) >= thresholdMs
}

const ISO_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/

/**
 * Yerel günün [başlangıç, sonraki günün başlangıcı) aralığı. Geçersiz biçimde RangeError.
 * DST günlerinde aralık 23 ya da 25 saat olabilir.
 */
export function localDayBounds(day: ISODate): { start: Date; end: Date } {
  const match = ISO_DATE_PATTERN.exec(day)
  const start = match
    ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
    : new Date(Number.NaN)
  if (Number.isNaN(start.getTime()) || toISODate(start) !== day) {
    throw new RangeError(`Geçersiz takvim günü: "${day}" (beklenen YYYY-MM-DD)`)
  }
  const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1)
  return { start, end }
}

/** Takvim adımında DST'den etkilenmemek için günün öğle saati kullanılır. */
const NOON_HOUR = 12

/**
 * `now`'un yerel gününde biten `count` günlük liste, ESKİDEN YENİYE (son eleman bugün).
 * count ≤ 0 → boş liste.
 */
export function recentDays(now: Date, count: number = RECENT_DAYS_COUNT): ISODate[] {
  const length = Math.max(0, Math.floor(count))
  return Array.from({ length }, (_, i) =>
    toISODate(
      new Date(now.getFullYear(), now.getMonth(), now.getDate() - (length - 1 - i), NOON_HOUR),
    ),
  )
}

/**
 * Belirli bir yerel gündeki toplam odak süresi (ms). Gece yarısını aşan segmentler bölünür;
 * yalnızca `sessions` içindeki (silinmemiş) oturumlara ait odak segmentleri sayılır.
 */
export function dailyFocusTotalMs(
  sessions: readonly FocusSession[],
  segments: readonly FocusSegment[],
  day: ISODate,
  now: Date,
): number {
  return focusMsInDay(countableFocusSegments(sessions, segments), day, now)
}

/** `days` sırasını koruyarak her gün için `dailyFocusTotalMs`. */
export function dailyFocusTotals(
  sessions: readonly FocusSession[],
  segments: readonly FocusSegment[],
  days: readonly ISODate[],
  now: Date,
): DailyFocusTotal[] {
  const countable = countableFocusSegments(sessions, segments)
  return days.map((day) => ({ day, focusMs: focusMsInDay(countable, day, now) }))
}

/** Silinmemiş oturumlara ait, silinmemiş odak segmentleri. */
function countableFocusSegments(
  sessions: readonly FocusSession[],
  segments: readonly FocusSegment[],
): FocusSegment[] {
  const sessionIds = new Set(sessions.filter(isLive).map((s) => s.id))
  return segments.filter((s) => isLive(s) && s.kind === 'focus' && sessionIds.has(s.sessionId))
}

function focusMsInDay(segments: readonly FocusSegment[], day: ISODate, now: Date): number {
  const { start, end } = localDayBounds(day)
  const dayStart = start.getTime()
  const dayEnd = end.getTime()
  return segments.reduce(
    (total, s) => total + overlapMs(toMs(s.startedAt), segmentEndMs(s, now), dayStart, dayEnd),
    0,
  )
}
