/** Ders listesi yardımcıları (saf). */
import type { ExamType, Subject, YksField } from '@/domain'

const EXAM_ORDER: Readonly<Record<ExamType, number>> = { TYT: 0, AYT: 1, YDT: 2 }

/** Kullanıcı tanımlı ders/konuların sıralama tabanı: katalog kayıtlarından sonra gelir. */
export const CUSTOM_ORDER_BASE = 1000

/** Katalog kaydı mı? Katalog ders/konuları düzenlenemez ve silinemez. */
export function isCatalogEntity(entity: { catalogKey: string | null }): boolean {
  return entity.catalogKey !== null
}

/**
 * Kullanıcının alanında görünen dersler: alanına ait katalog dersleri + tüm kullanıcı dersleri.
 * Sıra: sınav (TYT → AYT → YDT), sonra `order`, sonra ad (tr).
 */
export function visibleSubjects(subjects: readonly Subject[], field: YksField): Subject[] {
  return subjects
    .filter((s) => !isCatalogEntity(s) || s.fields.includes(field))
    .toSorted(
      (a, b) =>
        EXAM_ORDER[a.exam] - EXAM_ORDER[b.exam] ||
        a.order - b.order ||
        a.name.localeCompare(b.name, 'tr-TR'),
    )
}
