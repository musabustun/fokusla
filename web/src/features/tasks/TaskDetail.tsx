import { CalendarClock, Check, CircleAlert, Pencil, Repeat, Undo2 } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useServices } from '@/data'
import { completionRate, findCompletion, routineStreak } from '@/domain/calc/tasks'
import type { Task } from '@/domain'
import { Button, cx } from '@/ui'
import { formatLongDate, quantityText, recurrenceText } from './format'
import { buildRowModel, type RowContext } from './rowModel'
import type { SubjectGroup } from './subjectOptions'
import { DeleteControl, QuantityForm, RoutineStats } from './TaskDetailParts'
import { TaskFormFields } from './TaskForm'
import {
  deleteTask,
  draftFromTask,
  recordQuantity,
  toggleCompletion,
  updateTask,
} from './taskModel'
import { useAsyncAction } from './useAsyncAction'
import { useTaskForm } from './useTaskForm'

export interface TaskDetailProps {
  task: Task
  ctx: RowContext
  subjectGroups: readonly SubjectGroup[]
  /** Başlık `<h2>` olarak gösterilsin mi? (Sheet kendi başlığını gösterdiğinde false.) */
  showTitle?: boolean
  onDeleted: () => void
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5 first:pt-0 last:pb-0">
      <dt className="shrink-0 text-subheadline text-secondary-label">{label}</dt>
      <dd className="min-w-0 text-right text-subheadline break-words">{children}</dd>
    </div>
  )
}

function TaskFacts({ task, ctx }: { task: Task; ctx: RowContext }) {
  const model = buildRowModel(task, ctx)
  const target = quantityText(task.targetQuantity, null, task.quantityUnit)
  return (
    <dl className="divide-y divide-separator">
      <Fact label="Tür">{task.kind === 'routine' ? 'Rutin' : 'Ödev'}</Fact>
      {task.recurrence && <Fact label="Tekrar">{recurrenceText(task.recurrence)}</Fact>}
      {task.dueDate && (
        <Fact label="Son tarih">
          {formatLongDate(task.dueDate)}
          {model.due && (
            <span
              className={cx(
                'flex items-center justify-end gap-1',
                model.due.overdue ? 'font-semibold text-danger' : 'text-secondary-label',
              )}
            >
              {model.due.overdue && <CircleAlert aria-hidden className="size-3.5" />}
              {model.due.text}
            </span>
          )}
        </Fact>
      )}
      {model.subjectName && <Fact label="Ders">{model.subjectName}</Fact>}
      {target && <Fact label="Hedef">{target}</Fact>}
      {task.notes && (
        <Fact label="Not">
          <span className="whitespace-pre-wrap">{task.notes}</span>
        </Fact>
      )}
    </dl>
  )
}

interface EditTaskProps {
  task: Task
  ctx: RowContext
  subjectGroups: readonly SubjectGroup[]
  onDone: () => void
}

function EditTask({ task, ctx, subjectGroups, onDone }: EditTaskProps) {
  const { repositories } = useServices()
  const form = useTaskForm({
    initialDraft: draftFromTask(task),
    onSubmit: async (values) => {
      await updateTask(repositories, task.id, values)
      onDone()
    },
  })
  return (
    <TaskFormFields
      id={`task-edit-${task.id}`}
      form={form}
      subjectGroups={subjectGroups}
      today={ctx.today}
      kindLocked
    >
      <div className="flex justify-end gap-2">
        <Button variant="plain" onClick={onDone}>
          Vazgeç
        </Button>
        <Button type="submit" loading={form.saving}>
          Kaydet
        </Button>
      </div>
    </TaskFormFields>
  )
}

/** Görev ayrıntısı: bilgiler, rutin istatistiği, tamamla/geri al, miktar, düzenle ve sil. */
export function TaskDetail({
  task,
  ctx,
  subjectGroups,
  showTitle = true,
  onDeleted,
}: TaskDetailProps) {
  const { repositories } = useServices()
  const action = useAsyncAction()
  const [editing, setEditing] = useState(false)
  const model = buildRowModel(task, ctx)
  const isRoutine = task.kind === 'routine'
  const KindIcon = isRoutine ? Repeat : CalendarClock

  const toggle = () =>
    void action.run(() => toggleCompletion(repositories, task, ctx.today, new Date()))
  const saveQuantity = (quantity: number | null) =>
    void action.run(() => recordQuantity(repositories, task, ctx.today, new Date(), quantity))
  const remove = async () => {
    const ok = await action.run(() => deleteTask(repositories, task))
    if (ok) onDeleted()
  }

  return (
    <div className="flex flex-col gap-5">
      {showTitle && (
        <header className="flex items-start gap-3">
          <KindIcon aria-hidden className="mt-1 size-5 shrink-0 text-accent-ink" />
          <h2 className="min-w-0 text-title3 break-words">{task.title}</h2>
        </header>
      )}

      {editing ? (
        <EditTask
          task={task}
          ctx={ctx}
          subjectGroups={subjectGroups}
          onDone={() => setEditing(false)}
        />
      ) : (
        <>
          <TaskFacts task={task} ctx={ctx} />
          {isRoutine && (
            <RoutineStats
              rate={completionRate(task, ctx.completions, ctx.today)}
              streak={routineStreak(task, ctx.completions, ctx.today)}
            />
          )}

          <div className="flex flex-col gap-4">
            {model.done ? (
              <Button
                variant="tinted"
                fullWidth
                icon={<Undo2 aria-hidden className="size-5" />}
                loading={action.pending}
                onClick={toggle}
              >
                Geri al
              </Button>
            ) : (
              <Button
                fullWidth
                icon={<Check aria-hidden className="size-5" />}
                disabled={!model.canToggle}
                loading={action.pending}
                onClick={toggle}
              >
                Tamamla
              </Button>
            )}
            {model.canToggle ? (
              <QuantityForm
                key={`${task.id}-${String(model.done)}`}
                initial={
                  isRoutine
                    ? findCompletion(ctx.completions, task.id, ctx.today)?.quantity
                    : task.completedQuantity
                }
                unit={task.quantityUnit}
                pending={action.pending}
                onSave={saveQuantity}
              />
            ) : (
              <p className="text-footnote text-secondary-label">Bu rutin bugün planlı değil.</p>
            )}
          </div>

          {action.error && (
            <p
              role="alert"
              className="rounded-md bg-danger-subtle px-3 py-2 text-subheadline text-danger"
            >
              {action.error}
            </p>
          )}

          <div className="flex flex-wrap items-start gap-2 border-t border-separator pt-4">
            <Button
              variant="tinted"
              icon={<Pencil aria-hidden className="size-4" />}
              onClick={() => setEditing(true)}
            >
              Düzenle
            </Button>
            <DeleteControl pending={action.pending} onConfirm={() => void remove()} />
          </div>
        </>
      )}
    </div>
  )
}
