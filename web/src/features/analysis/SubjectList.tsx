import { Plus } from 'lucide-react'
import { Link } from 'react-router'
import { Button, cx, ListRow, ListSection } from '@/ui'
import type { ExamType, Subject, UUID } from '@/domain'
import type { TestSummary } from '@/domain/calc/tests'
import { analysisHref } from './analysisLinks'
import { subjectStatText } from './labels'

export interface SubjectListProps {
  subjects: readonly Subject[]
  subjectSummaries: ReadonlyMap<UUID, TestSummary>
  /** Seçili ders vurgulanır ve `aria-current="page"` alır. */
  selectedSubjectId?: UUID | null
  /** Dar sütun (iPad sol bölmesi): istatistik sağda değil, başlığın altında gösterilir. */
  compact?: boolean
  onAddSubject: () => void
}

const EXAMS: readonly ExamType[] = ['TYT', 'AYT', 'YDT']

/** Sınava göre gruplanmış ders listesi (iPhone genel bakışı ve iPad sol bölmesi). */
export function SubjectList({
  subjects,
  subjectSummaries,
  selectedSubjectId = null,
  compact = false,
  onAddSubject,
}: SubjectListProps) {
  const groups = EXAMS.map((exam) => ({
    exam,
    subjects: subjects.filter((s) => s.exam === exam),
  })).filter((g) => g.subjects.length > 0)

  return (
    <div>
      {groups.map((group) => (
        <ListSection key={group.exam} header={group.exam}>
          {group.subjects.map((subject) => {
            const stat = subjectStatText(subjectSummaries.get(subject.id))
            const isSelected = subject.id === selectedSubjectId
            return (
              <ListRow
                key={subject.id}
                title={subject.name}
                subtitle={compact ? stat : undefined}
                value={compact ? undefined : <span className="numeric text-label">{stat}</span>}
                render={(props) => (
                  <Link
                    to={analysisHref({ subjectId: subject.id })}
                    aria-current={isSelected ? 'page' : undefined}
                    className={cx(props.className, isSelected && 'bg-fill')}
                  >
                    {props.children}
                  </Link>
                )}
              />
            )
          })}
        </ListSection>
      ))}
      {groups.length === 0 && (
        <p className="mb-4 px-4 text-subheadline text-secondary-label">Henüz ders yok.</p>
      )}
      <Button variant="tinted" fullWidth icon={<Plus aria-hidden />} onClick={onAddSubject}>
        Ders ekle
      </Button>
    </div>
  )
}
