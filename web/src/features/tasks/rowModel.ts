import {
  COMPLETION_RATE_WINDOW_DAYS,
  completionRate,
  daysUntilDue,
  findCompletion,
  isCompletedOn,
  isOverdue,
  isScheduledOn,
  routineStreak,
} from '@/domain/calc/tasks'
import type { ISODate, Subject, Task, TaskCompletion } from '@/domain'
import { dueText, formatNumber, formatPercent, quantityText, recurrenceText } from './format'

export interface RowContext {
  completions: readonly TaskCompletion[]
  today: ISODate
  subjectsById: ReadonlyMap<string, Subject>
}

/** Bir görev satırının ekranda gösterilecek, hesaplanmış hali (saf). */
export interface TaskRowModel {
  task: Task
  /** Bugün itibarıyla tamamlanmış mı (onay kutusu). */
  done: boolean
  /** Bugün işaretlenebilir mi? (Planlı olmayan gündeki rutin: hayır.) */
  canToggle: boolean
  subjectName: string | null
  /** "50 soru" / "42/50 soru". */
  quantity: string | null
  /** Rutin serisi (yalnızca > 0 ise). */
  streak: number | null
  /** Rutin tekrar metni ("Her gün"…); yalnızca `detailed` modda. */
  recurrence: string | null
  /** "Son 7 gün %57"; yalnızca `detailed` modda ve planlı gün varsa. */
  rate: string | null
  /** Ödevin son tarih metni. */
  due: { text: string; overdue: boolean } | null
}

function actualQuantity(task: Task, ctx: RowContext): number | null | undefined {
  if (task.kind === 'assignment') return task.completedQuantity
  return findCompletion(ctx.completions, task.id, ctx.today)?.quantity
}

function rateText(task: Task, ctx: RowContext): string | null {
  const { rate } = completionRate(task, ctx.completions, ctx.today)
  if (rate === null) return null
  return `Son ${formatNumber(COMPLETION_RATE_WINDOW_DAYS)} gün ${formatPercent(rate)}`
}

export function buildRowModel(task: Task, ctx: RowContext, detailed = false): TaskRowModel {
  const isRoutine = task.kind === 'routine'
  const days = daysUntilDue(task, ctx.today)
  const streak = isRoutine ? routineStreak(task, ctx.completions, ctx.today) : 0
  return {
    task,
    done: isCompletedOn(task, ctx.completions, ctx.today),
    canToggle: !isRoutine || isScheduledOn(task, ctx.today),
    subjectName: task.subjectId ? (ctx.subjectsById.get(task.subjectId)?.name ?? null) : null,
    quantity: quantityText(task.targetQuantity, actualQuantity(task, ctx), task.quantityUnit),
    streak: streak > 0 ? streak : null,
    recurrence: detailed && task.recurrence ? recurrenceText(task.recurrence) : null,
    rate: detailed && isRoutine ? rateText(task, ctx) : null,
    due: days === null ? null : { text: dueText(days), overdue: isOverdue(task, ctx.today) },
  }
}
