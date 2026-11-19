/**
 * iOS dışa aktarımı: web kataloğunu (`yksCurriculum`) Swift `CurriculumCatalog` (Decodable)
 * ile birebir uyumlu, kararlı anahtar sıralı düz nesneye çevirir. Saf fonksiyon; dosya yazmaz.
 * Yazıcı: `web/scripts/export-ios-curriculum.ts` (`npm run export:ios-curriculum`).
 */
import type { Curriculum } from './types'

export function toIosCurriculumJson(curriculum: Curriculum): Curriculum {
  return {
    examYear: curriculum.examYear,
    sources: [...curriculum.sources],
    verifiedAt: curriculum.verifiedAt,
    subjects: curriculum.subjects.map((subject) => ({
      key: subject.key,
      name: subject.name,
      exam: subject.exam,
      fields: [...subject.fields],
      questionCount: subject.questionCount,
      topics: subject.topics.map((topic) => ({ key: topic.key, name: topic.name })),
    })),
  }
}
