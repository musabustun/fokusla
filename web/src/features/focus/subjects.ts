import type { ExamType, Subject, YksField } from '@/domain'

const EXAM_ORDER: readonly ExamType[] = ['TYT', 'AYT', 'YDT']

/** Profilin alanına ait dersler (profil yoksa hepsi), önce sınav sonra `order` sırasıyla. */
export function subjectsForField(
  subjects: readonly Subject[],
  field: YksField | undefined,
): Subject[] {
  return subjects
    .filter((subject) => field === undefined || subject.fields.includes(field))
    .sort(
      (a, b) =>
        EXAM_ORDER.indexOf(a.exam) - EXAM_ORDER.indexOf(b.exam) ||
        a.order - b.order ||
        a.name.localeCompare(b.name, 'tr-TR'),
    )
}

/** Sınava göre gruplanmış dersler (`<optgroup>` için), sınav sırası korunur. */
export function groupByExam(subjects: readonly Subject[]): [ExamType, Subject[]][] {
  return EXAM_ORDER.map((exam): [ExamType, Subject[]] => [
    exam,
    subjects.filter((subject) => subject.exam === exam),
  ]).filter(([, group]) => group.length > 0)
}
