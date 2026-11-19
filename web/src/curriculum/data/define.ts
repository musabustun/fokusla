/**
 * Katalog verisini yazmayı kolaylaştıran küçük yardımcı.
 *
 * Konuları `['konu-slug', 'Konu Adı']` çiftleri olarak yazarsın; tam anahtar
 * (`<dersAnahtarı>.<konu-slug>`) otomatik üretilir. Böylece ders anahtarını her satırda
 * tekrar yazmak ve yanlış yazmak gerekmez.
 */
import type { ExamType, YksField } from '@/domain'
import type { CatalogSubject } from '../types'

/** `[konu-slug, Konu Adı]` — slug ASCII kebab-case olmalı, ad Türkçe karakterlerle yazılır. */
export type TopicEntry = readonly [slug: string, name: string]

export interface SubjectDefinition {
  key: string
  name: string
  exam: ExamType
  fields: YksField[]
  questionCount: number | null
  topics: readonly TopicEntry[]
}

export const ALL_FIELDS: YksField[] = ['SAY', 'EA', 'SOZ', 'DIL']

export function defineSubject(definition: SubjectDefinition): CatalogSubject {
  return {
    key: definition.key,
    name: definition.name,
    exam: definition.exam,
    fields: [...definition.fields],
    questionCount: definition.questionCount,
    topics: definition.topics.map(([slug, name]) => ({ key: `${definition.key}.${slug}`, name })),
  }
}
