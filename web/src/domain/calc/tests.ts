/**
 * Test analizi hesapları — SAF fonksiyonlar (React/Dexie/Date.now yok). Sahibi: analysis oturumu.
 *
 * Net SAKLANMAZ: net = D − Y/4. Başarı = D / soru. Soru sayısı = D + Y + B.
 * Swift portunda aynı imzalar ve tests.test.ts'teki tablo vakaları kullanılır.
 */
import type { ISODate, ISODateTime, TestResult, UUID } from '../types'
import { toISODate } from '../ids'

/** YKS'de 4 yanlış 1 doğruyu götürür. */
export const WRONG_ANSWER_PENALTY = 0.25

/** "En zayıf konular" listesine girmek için bir konuda çözülmüş en az soru sayısı. */
export const MIN_QUESTIONS_FOR_WEAKNESS = 20

/** "En zayıf konular" listesinin varsayılan uzunluğu. */
export const DEFAULT_WEAK_TOPIC_LIMIT = 5

type Counts = Pick<TestResult, 'correct' | 'wrong' | 'blank'>

/** Net = doğru − yanlış × 0.25. Negatif olabilir. */
export function computeNet(result: Pick<TestResult, 'correct' | 'wrong'>): number {
  return result.correct - result.wrong * WRONG_ANSWER_PENALTY
}

/** Soru sayısı = doğru + yanlış + boş. */
export function questionCount(result: Counts): number {
  return result.correct + result.wrong + result.blank
}

/** Başarı oranı = doğru / soru (0–1); soru yoksa 0. */
export function accuracyOf(result: Counts): number {
  return ratio(result.correct, questionCount(result))
}

/** Pay / payda; payda 0 ise 0. */
function ratio(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : numerator / denominator
}

/** Anahtara göre gruplar; anahtar null ise sonuç atlanır. Girdi sırası korunur. */
function groupBy<K>(
  results: readonly TestResult[],
  keyOf: (result: TestResult) => K | null,
): Map<K, TestResult[]> {
  const groups = new Map<K, TestResult[]>()
  for (const result of results) {
    const key = keyOf(result)
    if (key === null) continue
    groups.set(key, [...(groups.get(key) ?? []), result])
  }
  return groups
}

function summarizeGroups<K>(groups: Map<K, TestResult[]>): Map<K, TestSummary> {
  return new Map([...groups].map(([key, group]) => [key, summarizeResults(group)]))
}

export interface TestSummary {
  /** Özetlenen test sonucu sayısı. */
  testCount: number
  totalQuestions: number
  correct: number
  wrong: number
  blank: number
  net: number
  /** Doğru / toplam soru (0–1); soru yoksa 0. */
  accuracy: number
  /** Net / toplam soru (−0.25…1); soru yoksa 0. Zayıflık sıralamasında kullanılır. */
  netRatio: number
  /** En son çözülen testin takenAt değeri; hiç test yoksa null. */
  lastTakenAt: ISODateTime | null
}

/** Bir grup test sonucunu (ör. bir konu) özetler. Boş liste → tüm sayılar 0, lastTakenAt null. */
export function summarizeResults(results: readonly TestResult[]): TestSummary {
  const totals = results.reduce(
    (acc, r) => ({
      correct: acc.correct + r.correct,
      wrong: acc.wrong + r.wrong,
      blank: acc.blank + r.blank,
      lastTakenAt:
        acc.lastTakenAt === null || r.takenAt > acc.lastTakenAt ? r.takenAt : acc.lastTakenAt,
    }),
    { correct: 0, wrong: 0, blank: 0, lastTakenAt: null as ISODateTime | null },
  )
  const totalQuestions = questionCount(totals)
  const net = computeNet(totals)
  return {
    testCount: results.length,
    totalQuestions,
    correct: totals.correct,
    wrong: totals.wrong,
    blank: totals.blank,
    net,
    accuracy: ratio(totals.correct, totalQuestions),
    netRatio: ratio(net, totalQuestions),
    lastTakenAt: totals.lastTakenAt,
  }
}

/** subjectId'ye göre gruplayıp özetler. Yalnızca en az bir sonucu olan dersler anahtar olur. */
export function summarizeBySubject(results: readonly TestResult[]): Map<UUID, TestSummary> {
  return summarizeGroups(groupBy(results, (r) => r.subjectId))
}

/**
 * topicId'ye göre gruplayıp özetler. topicId === null olan sonuçlar atlanır.
 * Yalnızca en az bir sonucu olan konular anahtar olur.
 */
export function summarizeByTopic(results: readonly TestResult[]): Map<UUID, TestSummary> {
  return summarizeGroups(groupBy(results, (r) => r.topicId))
}

export interface WeakTopic {
  topicId: UUID
  summary: TestSummary
}

export interface WeakTopicOptions {
  /** Varsayılan MIN_QUESTIONS_FOR_WEAKNESS. Bundan az sorusu olan konu listeye girmez. */
  minQuestions?: number
  /** Varsayılan DEFAULT_WEAK_TOPIC_LIMIT. */
  limit?: number
}

/**
 * En zayıf konular: eşiği geçen konular netRatio'ya göre ARTAN sıralanır.
 * Eşitlikte daha çok soru çözülmüş konu önce, o da eşitse topicId'ye göre (deterministik).
 */
export function findWeakestTopics(
  summaries: ReadonlyMap<UUID, TestSummary>,
  options?: WeakTopicOptions,
): WeakTopic[] {
  const minQuestions = options?.minQuestions ?? MIN_QUESTIONS_FOR_WEAKNESS
  const limit = options?.limit ?? DEFAULT_WEAK_TOPIC_LIMIT
  return [...summaries]
    .filter(([, summary]) => summary.totalQuestions >= minQuestions)
    .map(([topicId, summary]): WeakTopic => ({ topicId, summary }))
    .sort(compareWeakness)
    .slice(0, Math.max(0, limit))
}

function compareWeakness(a: WeakTopic, b: WeakTopic): number {
  if (a.summary.netRatio !== b.summary.netRatio) return a.summary.netRatio - b.summary.netRatio
  if (a.summary.totalQuestions !== b.summary.totalQuestions) {
    return b.summary.totalQuestions - a.summary.totalQuestions
  }
  return compareStrings(a.topicId, b.topicId)
}

/** Düz kod birimi karşılaştırması (locale yok, Swift'te `<` ile aynı): −1 / 0 / 1. */
function compareStrings(a: string, b: string): number {
  return Number(a > b) - Number(a < b)
}

export interface NetTrendPoint {
  /** Yerel takvim günü. */
  date: ISODate
  /** O gün çözülen testlerin özeti (net = günlük toplam net). */
  summary: TestSummary
}

/**
 * Günlük net trendi: sonuçları takenAt'in YEREL gününe (`toISODate` from '../ids') göre gruplar,
 * güne göre ARTAN sıralı noktalar döner. Boş liste → [].
 */
export function dailyNetTrend(results: readonly TestResult[]): NetTrendPoint[] {
  const byDay = groupBy(results, (r) => toISODate(new Date(r.takenAt)))
  return [...summarizeGroups(byDay)]
    .map(([date, summary]): NetTrendPoint => ({ date, summary }))
    .sort((a, b) => compareStrings(a.date, b.date))
}
