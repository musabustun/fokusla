/**
 * Görev hesapları — SAF fonksiyonlar. Sahibi: tasks feature oturumu.
 * `today` ekranı ve Swift port'u bunları kullanır; test tabloları Swift'e taşınacak.
 *
 * Kurallar:
 *  - `Date.now()` / `new Date()` (argümansız) ÇAĞRILMAZ; gün `day`/`today` parametresi olarak gelir.
 *  - Takvim günleri YEREL `ISODate` (`YYYY-MM-DD`). Gün aritmetiği ve hafta günü, saat diliminden
 *    bağımsız olsun diye `Date.UTC` ile yapılır (yalnızca ISODate → ISODate).
 *  - ISODateTime → yerel gün dönüşümü (`createdAt`, `completedAt`) `toISODate(new Date(x))` ile.
 *  - Soft-delete edilmiş görevler (`deletedAt != null`) ve tamamlamalar her fonksiyonda yok sayılır.
 *  - Aynı (taskId, date) için birden çok silinmemiş TaskCompletion olabilir (CloudKit): tek sayılır.
 *  - Girdi dizileri mutasyona uğramaz; yeni diziler döner.
 */
import type { ISODate, RecurrenceRule, Task, TaskCompletion, Weekday } from '../types'
import { toISODate } from '../ids'

/** Seri/oran penceresi: son 7 gün (bugün dahil). */
export const COMPLETION_RATE_WINDOW_DAYS = 7
/** "Yaklaşan" ödevler: bugünden sonraki bu kadar gün içinde son tarihi olanlar. */
export const UPCOMING_HORIZON_DAYS = 7

const MS_PER_DAY = 86_400_000

/** `YYYY-MM-DD` → o günün UTC gece yarısı (ms). Saat diliminden bağımsız gün aritmetiği için. */
function utcMidnight(day: ISODate): number {
  const year = Number(day.slice(0, 4))
  const month = Number(day.slice(5, 7))
  const date = Number(day.slice(8, 10))
  return Date.UTC(year, month - 1, date)
}

function fromUtcMidnight(ms: number): ISODate {
  const d = new Date(ms)
  const y = String(d.getUTCFullYear()).padStart(4, '0')
  const m = String(d.getUTCMonth() + 1).padStart(2, '0')
  const dd = String(d.getUTCDate()).padStart(2, '0')
  return `${y}-${m}-${dd}`
}

function isDeleted(entity: { deletedAt: string | null }): boolean {
  return entity.deletedAt !== null
}

/** `order`, sonra `title` (tr-TR). */
function compareByOrderThenTitle(a: Task, b: Task): number {
  return a.order - b.order || a.title.localeCompare(b.title, 'tr-TR')
}

/** Tarihsiz ödevleri sona atan sıralama anahtarı (her geçerli ISODate'ten büyüktür). */
const NO_DUE_DATE_SORT_KEY = '9999-99-99'

/** dueDate artan (null en sonda), sonra `order`, sonra `title` (tr-TR). */
function compareByDueDate(a: Task, b: Task): number {
  const dueA = a.dueDate ?? NO_DUE_DATE_SORT_KEY
  const dueB = b.dueDate ?? NO_DUE_DATE_SORT_KEY
  if (dueA !== dueB) return dueA < dueB ? -1 : 1
  return compareByOrderThenTitle(a, b)
}

/** ISO hafta günü (1 = Pazartesi … 7 = Pazar). Saat diliminden bağımsız. */
export function weekdayOf(day: ISODate): Weekday {
  const jsDay = new Date(utcMidnight(day)).getUTCDay() // 0 = Pazar
  return (jsDay === 0 ? 7 : jsDay) as Weekday
}

/** `day`'e `amount` gün ekler (negatif olabilir); ay/yıl/artık yıl geçişlerini doğru yapar. */
export function addDays(day: ISODate, amount: number): ISODate {
  return fromUtcMidnight(utcMidnight(day) + amount * MS_PER_DAY)
}

/** `to − from` gün farkı (to < from ise negatif). */
export function daysBetween(from: ISODate, to: ISODate): number {
  return Math.round((utcMidnight(to) - utcMidnight(from)) / MS_PER_DAY)
}

/**
 * Kural bu günde tekrar ediyor mu? `daily` → her gün. `weekly` → `weekdays` içeriyorsa;
 * `weekly` + boş `weekdays` → hiçbir gün (geçersiz kural, false).
 */
export function isDueOn(rule: RecurrenceRule, day: ISODate): boolean {
  if (rule.frequency === 'daily') return true
  return rule.weekdays.includes(weekdayOf(day))
}

/** Rutinin başladığı yerel gün: `startDate` varsa o, yoksa `createdAt`'in yerel günü. */
export function routineStartDate(task: Task): ISODate {
  return task.startDate ?? toISODate(new Date(task.createdAt))
}

/**
 * Rutin bu günde planlı mı? routine + silinmemiş + recurrence != null + day >= başlangıç günü +
 * isDueOn. Ödevler için her zaman false.
 */
export function isScheduledOn(task: Task, day: ISODate): boolean {
  if (task.kind !== 'routine' || isDeleted(task) || task.recurrence === null) return false
  if (day < routineStartDate(task)) return false
  return isDueOn(task.recurrence, day)
}

/** Ödevin tamamlandığı yerel gün (completedAt'ten); tamamlanmadıysa veya rutinse null. */
export function assignmentCompletionDay(task: Task): ISODate | null {
  if (task.kind !== 'assignment' || task.completedAt === null) return null
  return toISODate(new Date(task.completedAt))
}

/** Rutinin bu güne ait silinmemiş tamamlaması (birden çoksa en erken `completedAt`). */
export function findCompletion(
  completions: readonly TaskCompletion[],
  taskId: string,
  day: ISODate,
): TaskCompletion | undefined {
  let earliest: TaskCompletion | undefined
  for (const completion of completions) {
    if (completion.taskId !== taskId || completion.date !== day || isDeleted(completion)) continue
    if (earliest === undefined || completion.completedAt < earliest.completedAt) {
      earliest = completion
    }
  }
  return earliest
}

/**
 * Görev o gün tamamlanmış sayılır mı?
 * - routine: o güne ait silinmemiş TaskCompletion var.
 * - assignment: completedAt != null ve tamamlanma günü <= day (o güne kadar bitirilmiş).
 * - Silinmiş görev: false.
 */
export function isCompletedOn(
  task: Task,
  completions: readonly TaskCompletion[],
  day: ISODate,
): boolean {
  if (isDeleted(task)) return false
  if (task.kind === 'routine') return findCompletion(completions, task.id, day) !== undefined
  const completionDay = assignmentCompletionDay(task)
  return completionDay !== null && completionDay <= day
}

/** Ödev gecikmiş mi? assignment + silinmemiş + tamamlanmamış + dueDate != null + dueDate < today. */
export function isOverdue(task: Task, today: ISODate): boolean {
  return (
    task.kind === 'assignment' &&
    !isDeleted(task) &&
    task.completedAt === null &&
    task.dueDate !== null &&
    task.dueDate < today
  )
}

/** Geciken ödevler, en eski son tarih önce (eşitlikte `order`, sonra `title` tr-TR). */
export function overdueAssignments(tasks: readonly Task[], today: ISODate): Task[] {
  return tasks.filter((task) => isOverdue(task, today)).sort(compareByDueDate)
}

/** Son tarihe kalan gün (dueDate − today; geçmişse negatif). Ödev değilse/dueDate yoksa null. */
export function daysUntilDue(task: Task, today: ISODate): number | null {
  if (task.kind !== 'assignment' || task.dueDate === null) return null
  return daysBetween(today, task.dueDate)
}

/** Bir günün görev gündemi. Her grup kendi içinde sıralıdır. */
export interface DayAgenda {
  /** O gün planlı rutinler (`order`, sonra `title` tr-TR). */
  routines: Task[]
  /** dueDate < day: açık olanlar + o gün tamamlananlar (dueDate artan). */
  overdue: Task[]
  /** dueDate === day veya dueDate null: açık olanlar + o gün tamamlananlar. */
  dueToday: Task[]
  /** day < dueDate <= day + horizonDays: açık olanlar + o gün tamamlananlar (dueDate artan). */
  upcoming: Task[]
}

/**
 * Ödev bu günün gündeminde görünür mü? `day` itibarıyla açık (henüz tamamlanmamış ya da daha
 * SONRAKİ bir günde tamamlanmış) VEYA tam o gün tamamlanmış. Daha önce tamamlanan hariç.
 */
function isAssignmentVisibleOn(task: Task, day: ISODate): boolean {
  const completionDay = assignmentCompletionDay(task)
  return completionDay === null || completionDay >= day
}

/**
 * Günün gündemi ("Bugün" görünümü). Ödev, (açık ve gündem aralığında) VEYA (tamamlanma günü ===
 * day) ise dahil edilir — böylece o gün tamamlanan ödev listede kalır ve geri alınabilir.
 * Daha önceki bir günde tamamlanmış ödev dahil edilmez. Silinmiş görevler hariç.
 *
 * Not: "açık", `day` itibarıyla değerlendirilir (isCompletedOn ile tutarlı): geçmiş bir gün
 * görüntülenirken o günden SONRA tamamlanmış ödev o gün için açık sayılır.
 * `dueToday` içinde önce son tarihi bugün olanlar, sonra tarihsizler gelir (her biri order/title).
 */
export function agendaForDay(
  tasks: readonly Task[],
  day: ISODate,
  horizonDays: number = UPCOMING_HORIZON_DAYS,
): DayAgenda {
  const horizonEnd = addDays(day, horizonDays)
  const routines: Task[] = []
  const overdue: Task[] = []
  const dueToday: Task[] = []
  const upcoming: Task[] = []

  for (const task of tasks) {
    if (task.kind === 'routine') {
      if (isScheduledOn(task, day)) routines.push(task)
      continue
    }
    if (isDeleted(task) || !isAssignmentVisibleOn(task, day)) continue
    const due = task.dueDate
    if (due === null || due === day) dueToday.push(task)
    else if (due < day) overdue.push(task)
    else if (due <= horizonEnd) upcoming.push(task)
  }

  return {
    routines: routines.sort(compareByOrderThenTitle),
    overdue: overdue.sort(compareByDueDate),
    dueToday: dueToday.sort(compareByDueDate),
    upcoming: upcoming.sort(compareByDueDate),
  }
}

/** Belirli bir gün için gösterilecek görevler: agendaForDay gruplarının sırayla birleşimi. */
export function tasksForDay(tasks: readonly Task[], day: ISODate): Task[] {
  const agenda = agendaForDay(tasks, day)
  return [...agenda.routines, ...agenda.overdue, ...agenda.dueToday, ...agenda.upcoming]
}

/**
 * Rutin serisi: `today`den geriye doğru, planlı günlerde kesintisiz tamamlama sayısı.
 * Planlı olmayan günler atlanır (seriyi bozmaz). Bugün planlı ama henüz tamamlanmadıysa seri
 * BOZULMAZ (bir önceki planlı günden saymaya başlanır). Başlangıç gününden önceye bakılmaz.
 * Rutin değilse/silinmişse 0.
 */
export function routineStreak(
  task: Task,
  completions: readonly TaskCompletion[],
  today: ISODate,
): number {
  if (task.kind !== 'routine' || isDeleted(task) || task.recurrence === null) return 0
  const start = routineStartDate(task)
  let streak = 0
  for (let day = today; day >= start; day = addDays(day, -1)) {
    if (!isScheduledOn(task, day)) continue
    if (findCompletion(completions, task.id, day) !== undefined) streak += 1
    else if (day !== today) break
  }
  return streak
}

export interface CompletionRate {
  /** Penceredeki planlı gün sayısı (başlangıçtan önceki günler hariç). */
  scheduled: number
  /** Bunlardan tamamlananların sayısı. */
  completed: number
  /** completed / scheduled (0–1); planlı gün yoksa null. */
  rate: number | null
}

/** Son `windowDays` gün (bugün dahil: [today − windowDays + 1, today]) tamamlama oranı. */
export function completionRate(
  task: Task,
  completions: readonly TaskCompletion[],
  today: ISODate,
  windowDays: number = COMPLETION_RATE_WINDOW_DAYS,
): CompletionRate {
  let scheduled = 0
  let completed = 0
  for (let offset = 0; offset < windowDays; offset += 1) {
    const day = addDays(today, -offset)
    if (!isScheduledOn(task, day)) continue
    scheduled += 1
    if (findCompletion(completions, task.id, day) !== undefined) completed += 1
  }
  return { scheduled, completed, rate: scheduled === 0 ? null : completed / scheduled }
}
