import type { ExamType, Subject, YksField } from '@/domain'

export interface SubjectGroup {
  exam: ExamType
  subjects: Subject[]
}

const EXAM_ORDER: readonly ExamType[] = ['TYT', 'AYT', 'YDT']

function compareSubjects(a: Subject, b: Subject): number {
  return a.order - b.order || a.name.localeCompare(b.name, 'tr-TR')
}

/**
 * "Ders" seçicisinin grupları: yalnızca profil alanının gördüğü dersler (alan yoksa hepsi),
 * TYT/AYT/YDT sırasıyla ve `order`'a göre. `keepId` (düzenlenen görevin mevcut dersi) alan
 * dışında kalsa bile listede tutulur, böylece düzenlerken kaybolmaz.
 */
export function subjectGroups(
  subjects: readonly Subject[],
  field: YksField | undefined,
  keepId?: string | null,
): SubjectGroup[] {
  const visible = subjects.filter(
    (subject) =>
      subject.deletedAt === null &&
      (field === undefined || subject.fields.includes(field) || subject.id === keepId),
  )
  return EXAM_ORDER.map((exam) => ({
    exam,
    subjects: visible.filter((subject) => subject.exam === exam).sort(compareSubjects),
  })).filter((group) => group.subjects.length > 0)
}
