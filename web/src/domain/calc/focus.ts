/**
 * Odak hesapları — SAF fonksiyonlar (React/Dexie yok). Sahibi: focus feature oturumu.
 * Tüm süreler zaman damgalarından hesaplanır; açık segmentler `now` ile kapatılmış sayılır.
 * Birim: milisaniye.
 */
import type { FocusSegment, FocusSession, ISODate } from '../types'
import { NotImplementedError } from './notImplemented'

export interface FocusSessionStats {
  /** Toplam odak süresi (ms). */
  focusMs: number
  /** Toplam mola süresi (ms). */
  breakMs: number
  /** Odak segmenti sayısı. */
  focusCount: number
  /** Mola segmenti sayısı. */
  breakCount: number
  /** Ortalama kesintisiz odak süresi (ms); hiç odak segmenti yoksa 0. */
  averageFocusMs: number
  /** Ortalama mola süresi (ms); hiç mola yoksa 0. */
  averageBreakMs: number
}

/** Bir segmentin süresi (ms). Açık segment için `now` kullanılır. */
export function segmentDurationMs(_segment: FocusSegment, _now: Date): number {
  throw new NotImplementedError('segmentDurationMs')
}

/** Bir oturumun segmentlerinden istatistik üretir. */
export function computeSessionStats(
  _segments: readonly FocusSegment[],
  _now: Date,
): FocusSessionStats {
  throw new NotImplementedError('computeSessionStats')
}

/** Belirli bir yerel gündeki toplam odak süresi (ms). Gece yarısını aşan segmentler bölünür. */
export function dailyFocusTotalMs(
  _sessions: readonly FocusSession[],
  _segments: readonly FocusSegment[],
  _day: ISODate,
  _now: Date,
): number {
  throw new NotImplementedError('dailyFocusTotalMs')
}
