/**
 * YKS müfredat kataloğu tipleri. Katalog saf veridir; veri katmanı onu Subject/Topic
 * kayıtları olarak IndexedDB'ye tohumlar (catalogKey ile eşleştirerek, idempotent).
 */
import type { ExamType, YksField } from '@/domain'

export interface CatalogTopic {
  /** Stabil, ASLA değişmeyen anahtar. Biçim: `<subjectKey>.<konu-slug>`, ör. `tyt-matematik.temel-kavramlar`. */
  key: string
  name: string
}

export interface CatalogSubject {
  /** Stabil anahtar, ör. `tyt-matematik`, `ayt-fizik`. */
  key: string
  name: string
  exam: ExamType
  /** Bu dersi sınavında gören alanlar. */
  fields: YksField[]
  /** Toplam soru sayısı (o sınav oturumunda bu derse ait). Bilinmiyorsa null. */
  questionCount: number | null
  topics: CatalogTopic[]
}

export interface Curriculum {
  /** Kataloğun geçerli olduğu sınav yılı, ör. 2026. */
  examYear: number
  /** Kaynak açıklaması ve URL'ler. */
  sources: string[]
  /** Son doğrulama tarihi (YYYY-MM-DD). */
  verifiedAt: string
  subjects: CatalogSubject[]
}
