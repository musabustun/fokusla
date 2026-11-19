import { useId, type ChangeEvent } from 'react'
import { useLiveData, useServices } from '@/data'
import type { Subject, UUID } from '@/domain'
import { cx, FIELD_LABEL_CLASS, inputStyles } from '@/ui'
import { groupByExam } from './subjects'

export interface SubjectSelection {
  subjectId: UUID | null
  topicId: UUID | null
}

export interface SubjectPickerProps {
  /** Gösterilecek dersler (alanına göre süzülmüş ve sıralanmış). */
  subjects: readonly Subject[]
  value: SubjectSelection
  onChange: (value: SubjectSelection) => void
}

const SELECT_CLASS = cx(inputStyles(), 'disabled:cursor-not-allowed')
const LABEL_CLASS = cx(FIELD_LABEL_CLASS, 'mb-1.5 block')

/** Opsiyonel ders ve konu seçimi; konu yalnızca ders seçildikten sonra etkinleşir. */
export function SubjectPicker({ subjects, value, onChange }: SubjectPickerProps) {
  const { repositories } = useServices()
  const subjectSelectId = useId()
  const topicSelectId = useId()
  const { subjectId, topicId } = value
  const topics = useLiveData(
    () => (subjectId ? repositories.topics.findBySubject(subjectId) : Promise.resolve([])),
    [repositories, subjectId],
  )
  const sortedTopics = [...(topics ?? [])].sort((a, b) => a.order - b.order)

  const handleSubject = (event: ChangeEvent<HTMLSelectElement>) => {
    onChange({ subjectId: event.target.value || null, topicId: null })
  }
  const handleTopic = (event: ChangeEvent<HTMLSelectElement>) => {
    onChange({ subjectId, topicId: event.target.value || null })
  }

  return (
    <div className="flex flex-col gap-3">
      <div>
        <label htmlFor={subjectSelectId} className={LABEL_CLASS}>
          Ders (isteğe bağlı)
        </label>
        <select
          id={subjectSelectId}
          className={SELECT_CLASS}
          value={subjectId ?? ''}
          onChange={handleSubject}
        >
          <option value="">Ders seçilmedi</option>
          {groupByExam(subjects).map(([exam, group]) => (
            <optgroup key={exam} label={exam}>
              {group.map((subject) => (
                <option key={subject.id} value={subject.id}>
                  {subject.name}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </div>
      <div>
        <label htmlFor={topicSelectId} className={LABEL_CLASS}>
          Konu (isteğe bağlı)
        </label>
        <select
          id={topicSelectId}
          className={SELECT_CLASS}
          value={topicId ?? ''}
          onChange={handleTopic}
          disabled={!subjectId}
        >
          <option value="">Konu seçilmedi</option>
          {sortedTopics.map((topic) => (
            <option key={topic.id} value={topic.id}>
              {topic.name}
            </option>
          ))}
        </select>
      </div>
    </div>
  )
}
