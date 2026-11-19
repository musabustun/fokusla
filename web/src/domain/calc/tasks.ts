/** Görev hesapları — SAF fonksiyonlar. Sahibi: tasks feature oturumu. */
import type { ISODate, RecurrenceRule, Task, TaskCompletion } from '../types'
import { NotImplementedError } from './notImplemented'

/** Rutin bu günde yapılmalı mı? */
export function isDueOn(_rule: RecurrenceRule, _day: ISODate): boolean {
  throw new NotImplementedError('isDueOn')
}

/** Belirli bir gün için gösterilecek görevler (o günün rutinleri + açık/son tarihi gelen ödevler). */
export function tasksForDay(_tasks: readonly Task[], _day: ISODate): Task[] {
  throw new NotImplementedError('tasksForDay')
}

/** Görev o gün tamamlandı mı? (rutin → TaskCompletion, ödev → completedAt) */
export function isCompletedOn(
  _task: Task,
  _completions: readonly TaskCompletion[],
  _day: ISODate,
): boolean {
  throw new NotImplementedError('isCompletedOn')
}
