/**
 * Katalog yardımcıları — onboarding alan seçimi ve tohumlama için.
 */
import type { YksField } from '@/domain'
import type { CatalogSubject, Curriculum } from './types'

/** Puan türlerinin Türkçe adları. */
export const FIELD_LABELS: Readonly<Record<YksField, string>> = {
  SAY: 'Sayısal',
  EA: 'Eşit Ağırlık',
  SOZ: 'Sözel',
  DIL: 'Dil',
}

/** Alan seçimi ekranı için kısa açıklamalar (ÖSYM 2026-YKS Kılavuzu, Tablo 1E). */
export const FIELD_DESCRIPTIONS: Readonly<Record<YksField, string>> = {
  SAY: 'TYT ile birlikte AYT Matematik ve Fen Bilimleri (Fizik, Kimya, Biyoloji) testlerine girersin.',
  EA: 'TYT ile birlikte AYT Matematik ile Edebiyat, Tarih-1 ve Coğrafya-1 testlerine girersin.',
  SOZ: 'TYT ile birlikte AYT Edebiyat-Sosyal Bilimler-1 ve Sosyal Bilimler-2 testlerine girersin.',
  DIL: 'TYT ile birlikte AYT yerine Yabancı Dil Testi (YDT) sınavına girersin.',
}

/**
 * Bir alanın çalışacağı dersler: tüm TYT dersleri + o alanın AYT/YDT dersleri,
 * katalogdaki sırayla (önce TYT, sonra AYT, sonra YDT).
 */
export function subjectsForField(curriculum: Curriculum, field: YksField): CatalogSubject[] {
  return curriculum.subjects.filter((subject) => subject.fields.includes(field))
}

/** Anahtara göre ders bulur; yoksa `undefined`. */
export function findSubject(curriculum: Curriculum, key: string): CatalogSubject | undefined {
  return curriculum.subjects.find((subject) => subject.key === key)
}
