import { Check, ChevronRight, CircleAlert, Flame } from 'lucide-react'
import { Fragment, useId, type ReactNode } from 'react'
import { cx } from '@/ui'
import { streakText } from './format'
import type { TaskRowModel } from './rowModel'

export interface TaskRowProps {
  model: TaskRowModel
  selected?: boolean
  onToggle: (model: TaskRowModel) => void
  onSelect: (model: TaskRowModel) => void
}

function subtitleParts(model: TaskRowModel): ReactNode[] {
  const parts: ReactNode[] = []
  if (model.due) {
    parts.push(
      model.due.overdue ? (
        <span className="inline-flex items-center gap-1 font-semibold text-danger">
          <CircleAlert aria-hidden className="size-3.5 shrink-0" strokeWidth={2.5} />
          {model.due.text}
        </span>
      ) : (
        model.due.text
      ),
    )
  }
  if (model.recurrence) parts.push(model.recurrence)
  if (model.subjectName) parts.push(model.subjectName)
  if (model.quantity) parts.push(model.quantity)
  if (model.streak !== null) {
    parts.push(
      <span className="inline-flex items-center gap-1">
        <Flame aria-hidden className="size-3.5 shrink-0 text-warning" strokeWidth={2.5} />
        {streakText(model.streak)}
      </span>,
    )
  }
  if (model.rate) parts.push(model.rate)
  return parts
}

/** Yuvarlak onay kutusu: erişilebilir adı tam olarak görev başlığıdır. */
function CheckControl({ model, onToggle }: Pick<TaskRowProps, 'model' | 'onToggle'>) {
  const { done, canToggle, task } = model
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={done}
      aria-label={task.title}
      disabled={!canToggle}
      onClick={() => onToggle(model)}
      className="group flex size-11 shrink-0 items-center justify-center rounded-full disabled:cursor-not-allowed disabled:opacity-40"
    >
      <span
        aria-hidden
        className={cx(
          'flex size-6 items-center justify-center rounded-full border-2 motion-safe:transition-colors',
          done ? 'border-success bg-success text-surface' : 'border-tertiary-label',
        )}
      >
        {done && <Check className="size-4" strokeWidth={3} />}
      </span>
    </button>
  )
}

/** Görev satırı (iOS liste satırı görünümü): onay kutusu + ayrıntı düğmesi. */
export function TaskRow({ model, selected = false, onToggle, onSelect }: TaskRowProps) {
  const parts = subtitleParts(model)
  const subtitleId = useId()
  return (
    <li
      className={cx(
        'relative flex items-stretch pl-2',
        'before:absolute before:top-0 before:right-0 before:left-14 before:h-px before:bg-separator first:before:hidden',
        selected && 'bg-accent-subtle',
      )}
    >
      <div className="flex items-center">
        <CheckControl model={model} onToggle={onToggle} />
      </div>
      <button
        type="button"
        aria-label={`Ayrıntılar: ${model.task.title}`}
        aria-current={selected || undefined}
        aria-describedby={parts.length > 0 ? subtitleId : undefined}
        onClick={() => onSelect(model)}
        className="flex min-h-11 min-w-0 flex-1 items-center gap-3 py-2.5 pr-4 pl-1 text-left active:bg-fill motion-safe:transition-colors"
      >
        <span className="flex min-w-0 flex-1 flex-col">
          <span
            className={cx(
              'text-body break-words',
              model.done ? 'text-secondary-label line-through' : 'text-label',
            )}
          >
            {model.task.title}
          </span>
          {parts.length > 0 && (
            <span id={subtitleId} className="text-subheadline text-secondary-label">
              {parts.map((part, index) => (
                <Fragment key={index}>
                  {index > 0 && <span className="text-tertiary-label"> · </span>}
                  {part}
                </Fragment>
              ))}
            </span>
          )}
        </span>
        <ChevronRight
          aria-hidden
          className="size-5 shrink-0 text-tertiary-label"
          strokeWidth={2.5}
        />
      </button>
    </li>
  )
}
