/**
 * Bugün ekranının TEK yazma eylemi: görev tamamla/geri al. Ne yazılacağına `planTaskToggle`
 * (domain/calc/today.ts) karar verir; burada yalnızca o plan repository'lerle uygulanır.
 * Davranış Görevler modülünün `toggleCompletion`'ı ile aynıdır (miktarsız tamamlama).
 */
import type { Repositories } from '@/data'
import { toISODateTime } from '@/domain'
import type { TaskToggleAction } from '@/domain/calc/today'

/** Planı uygular. Repository hataları yutulmaz; çağıran gösterir. */
export async function applyTaskToggle(
  repositories: Repositories,
  action: TaskToggleAction,
  now: Date,
): Promise<void> {
  switch (action.kind) {
    case 'createCompletion':
      await repositories.taskCompletions.create({
        taskId: action.taskId,
        date: action.date,
        completedAt: toISODateTime(now),
        quantity: null,
      })
      return
    case 'deleteCompletions':
      for (const id of action.completionIds) {
        await repositories.taskCompletions.delete(id)
      }
      return
    case 'setAssignmentCompleted':
      await repositories.tasks.update(action.taskId, {
        completedAt: action.completed ? toISODateTime(now) : null,
        completedQuantity: null,
      })
      return
    case 'none':
      return
  }
}
