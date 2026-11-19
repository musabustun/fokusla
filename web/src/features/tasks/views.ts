/** "Bugün" ve "Tümü" görünümlerinin bölümleri (saf; bileşenlerden bağımsız test edilir). */
import { agendaForDay } from '@/domain/calc/tasks'
import type { Task } from '@/domain'
import { buildRowModel, type RowContext, type TaskRowModel } from './rowModel'

export interface ViewSection {
  key: string
  title: string
  rows: TaskRowModel[]
}

export interface ViewResult {
  sections: ViewSection[]
  /** Gizleme uygulanmadan önce görünümde en az bir görev var mı? */
  hasTasks: boolean
}

function byTitle(a: Task, b: Task): number {
  return a.title.localeCompare(b.title, 'tr-TR')
}

function byOrder(a: Task, b: Task): number {
  return a.order - b.order || byTitle(a, b)
}

function byDueDate(a: Task, b: Task): number {
  if (a.dueDate === b.dueDate) return byOrder(a, b)
  if (a.dueDate === null) return 1
  if (b.dueDate === null) return -1
  return a.dueDate.localeCompare(b.dueDate)
}

function byCompletedDesc(a: Task, b: Task): number {
  return (b.completedAt ?? '').localeCompare(a.completedAt ?? '') || byOrder(a, b)
}

function finish(sections: ViewSection[], hideCompleted: boolean): ViewResult {
  const hasTasks = sections.some((section) => section.rows.length > 0)
  const visible = sections
    .map((section) =>
      hideCompleted ? { ...section, rows: section.rows.filter((row) => !row.done) } : section,
    )
    .filter((section) => section.rows.length > 0)
  return { sections: visible, hasTasks }
}

/** "Bugün": Rutinler, Geciken, Bugün teslim, Yaklaşan (boş bölümler çıkarılır). */
export function todayView(
  tasks: readonly Task[],
  ctx: RowContext,
  hideCompleted: boolean,
): ViewResult {
  const agenda = agendaForDay(tasks, ctx.today)
  const rows = (list: readonly Task[]) => list.map((task) => buildRowModel(task, ctx))
  return finish(
    [
      { key: 'routines', title: 'Rutinler', rows: rows(agenda.routines) },
      { key: 'overdue', title: 'Geciken', rows: rows(agenda.overdue) },
      { key: 'dueToday', title: 'Bugün teslim', rows: rows(agenda.dueToday) },
      { key: 'upcoming', title: 'Yaklaşan', rows: rows(agenda.upcoming) },
    ],
    hideCompleted,
  )
}

/**
 * "Tümü": tüm rutinler (tekrar + seri + son 7 gün oranı), açık ödevler (son tarihe göre) ve
 * tamamlanan ödevler (en yeni önce; gizleme açıkken çıkarılır).
 */
export function allView(
  tasks: readonly Task[],
  ctx: RowContext,
  hideCompleted: boolean,
): ViewResult {
  const live = tasks.filter((task) => task.deletedAt === null)
  const rows = (list: Task[]) => list.map((task) => buildRowModel(task, ctx, true))
  const routines = live.filter((task) => task.kind === 'routine').sort(byOrder)
  const assignments = live.filter((task) => task.kind === 'assignment')
  const open = assignments.filter((task) => task.completedAt === null).sort(byDueDate)
  const completed = assignments.filter((task) => task.completedAt !== null).sort(byCompletedDesc)

  const sections: ViewSection[] = [
    // Rutinler her gün yenilenir; gizleme yalnızca tamamlanan ödevlere uygulanır.
    { key: 'routines', title: 'Rutinler', rows: rows(routines) },
    { key: 'assignments', title: 'Ödevler', rows: rows(open) },
  ]
  const hasTasks = live.length > 0
  const result = finish(sections, false)
  if (hideCompleted) return { sections: result.sections, hasTasks }
  const completedRows = rows(completed)
  const completedSection =
    completedRows.length > 0
      ? [{ key: 'completed', title: 'Tamamlanan ödevler', rows: completedRows }]
      : []
  return { sections: [...result.sections, ...completedSection], hasTasks }
}
