import { useId } from 'react'
import type { TaskRowModel } from './rowModel'
import { TaskRow } from './TaskRow'

export interface TaskSectionProps {
  title: string
  rows: readonly TaskRowModel[]
  selectedId: string | null
  onToggle: (model: TaskRowModel) => void
  onSelect: (model: TaskRowModel) => void
}

/** Başlıklı görev listesi (iOS inset grouped bölüm). Boşsa hiç çizilmez. */
export function TaskSection({ title, rows, selectedId, onToggle, onSelect }: TaskSectionProps) {
  const headingId = useId()
  if (rows.length === 0) return null
  return (
    <section aria-labelledby={headingId} className="mb-8">
      <h2 id={headingId} className="mb-1.5 px-4 text-footnote text-secondary-label uppercase">
        {title}
      </h2>
      <ul role="list" className="overflow-hidden rounded-lg bg-surface">
        {rows.map((row) => (
          <TaskRow
            key={row.task.id}
            model={row}
            selected={row.task.id === selectedId}
            onToggle={onToggle}
            onSelect={onSelect}
          />
        ))}
      </ul>
    </section>
  )
}
