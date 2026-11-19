/** Analiz satırlarının Türkçe metinleri (saf). */
import type { Book, TestResult, UUID } from '@/domain'
import type { TestSummary } from '@/domain/calc/tests'
import {
  formatAnswerCounts,
  formatDateTime,
  formatNet,
  formatPercent,
  formatQuestionCount,
  formatShortDateTime,
} from './format'

export const NO_RESULTS_TEXT = 'Henüz test yok'
export const UNKNOWN_SOURCE_TEXT = 'Kaynak belirtilmedi'

function hasResults(summary: TestSummary | undefined): summary is TestSummary {
  return Boolean(summary && summary.testCount > 0)
}

/** Ders satırı: "12,75 net · %64" ya da "Henüz test yok". */
export function subjectStatText(summary: TestSummary | undefined): string {
  if (!hasResults(summary)) return NO_RESULTS_TEXT
  return `${formatNet(summary.net)} net · ${formatPercent(summary.accuracy)}`
}

/** Konu satırı değeri: "%75 · 12,75 net" ya da "Henüz test yok". */
export function topicStatText(summary: TestSummary | undefined): string {
  if (!hasResults(summary)) return NO_RESULTS_TEXT
  return `${formatPercent(summary.accuracy)} · ${formatNet(summary.net)} net`
}

/** Konu satırı alt başlığı: "24 soru · son 19 Kas"; test yoksa undefined. */
export function topicDetailText(summary: TestSummary | undefined): string | undefined {
  if (!hasResults(summary)) return undefined
  const questions = formatQuestionCount(summary.totalQuestions)
  return summary.lastTakenAt
    ? `${questions} · son ${formatShortDateTime(summary.lastTakenAt)}`
    : questions
}

/** Test satırı başlığı: kitap adı / serbest kaynak + etiket, ör. "Karekök · Test 12". */
export function resultTitle(result: TestResult, booksById: ReadonlyMap<UUID, Book>): string {
  const book = result.bookId ? booksById.get(result.bookId) : undefined
  const source = book?.title ?? (result.sourceName?.trim() || null)
  const label = result.label?.trim() || null
  if (source && label) return `${source} · ${label}`
  return source ?? label ?? UNKNOWN_SOURCE_TEXT
}

/** Test satırı alt başlığı: "19 Kas 2026 · 12D 4Y 4B". */
export function resultSubtitle(result: TestResult): string {
  return `${formatDateTime(result.takenAt)} · ${formatAnswerCounts(result)}`
}
