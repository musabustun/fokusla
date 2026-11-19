/** Test analizi hesapları — SAF fonksiyonlar. Sahibi: analysis feature oturumu. */
import type { TestResult } from '../types'
import { NotImplementedError } from './notImplemented'

/** YKS'de 4 yanlış 1 doğruyu götürür. */
export const WRONG_ANSWER_PENALTY = 0.25

/** Net = doğru − yanlış × 0.25. */
export function computeNet(_result: Pick<TestResult, 'correct' | 'wrong'>): number {
  throw new NotImplementedError('computeNet')
}

export interface TestSummary {
  totalQuestions: number
  correct: number
  wrong: number
  blank: number
  net: number
  /** Doğru / toplam soru (0–1); soru yoksa 0. */
  accuracy: number
}

/** Bir grup test sonucunu (ör. bir konu) özetler. */
export function summarizeResults(_results: readonly TestResult[]): TestSummary {
  throw new NotImplementedError('summarizeResults')
}
