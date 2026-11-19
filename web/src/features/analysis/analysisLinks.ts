/** Analiz ekranının URL şeması: /analiz?ders=<subjectId>&konu=<topicId> (yeni rota yok). */
import { ROUTES } from '@/app/routes'
import type { UUID } from '@/domain'

export const SUBJECT_PARAM = 'ders'
export const TOPIC_PARAM = 'konu'

export interface AnalysisSelection {
  subjectId?: UUID | null
  topicId?: UUID | null
}

/** Seçime göre Analiz bağlantısı. Konu yalnızca bir dersle birlikte anlamlıdır. */
export function analysisHref({ subjectId, topicId }: AnalysisSelection = {}): string {
  if (!subjectId) return ROUTES.analysis
  const params = new URLSearchParams({ [SUBJECT_PARAM]: subjectId })
  if (topicId) params.set(TOPIC_PARAM, topicId)
  return `${ROUTES.analysis}?${params.toString()}`
}

/** URL arama parametrelerinden seçimi okur; boş değerler null olur. */
export function readSelection(params: URLSearchParams): {
  subjectId: UUID | null
  topicId: UUID | null
} {
  const subjectId = params.get(SUBJECT_PARAM) || null
  const topicId = subjectId ? params.get(TOPIC_PARAM) || null : null
  return { subjectId, topicId }
}

/** Genel bakışın başlığı ve geri bağlantısının hedef adı. */
export const ANALYSIS_TITLE = 'Analiz'
