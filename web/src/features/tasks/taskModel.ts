/**
 * Görevler feature'ının UI'dan bağımsız modeli: form taslağı, doğrulama ve repository eylemleri.
 * Ekranlar (TasksScreen, TaskForm, TaskDetail…) yalnızca bunları çağırır.
 * Saat bilgisi her zaman `now: Date` parametresiyle gelir (testte sabitlenir).
 */
import type { Repositories } from '@/data'
import type {
  EntityPatch,
  ISODate,
  NewEntity,
  Task,
  TaskCompletion,
  TaskKind,
  Weekday,
} from '@/domain'
import { toISODateTime } from '@/domain'

export const TITLE_MAX_LENGTH = 120
export const NOTES_MAX_LENGTH = 1000
export const QUANTITY_MAX = 10_000
export const UNIT_MAX_LENGTH = 24

/** Formun ham (string tabanlı) durumu. */
export interface TaskDraft {
  kind: TaskKind
  title: string
  notes: string
  /** '' = ders yok. */
  subjectId: string
  /** Rutin: 'daily' | 'weekly'. */
  frequency: 'daily' | 'weekly'
  /** Rutin + weekly: seçili günler (sıralı tutulur). */
  weekdays: Weekday[]
  /** Ödev: 'YYYY-MM-DD' ('' = girilmedi). */
  dueDate: string
  /** '' = hedef yok; aksi halde pozitif tam sayı metni. */
  targetQuantity: string
  quantityUnit: string
}

export type TaskDraftField =
  'title' | 'notes' | 'weekdays' | 'dueDate' | 'targetQuantity' | 'quantityUnit'

/** Alan → Türkçe hata mesajı. */
export type TaskDraftErrors = Partial<Record<TaskDraftField, string>>

export type DraftValidation =
  { ok: true; value: TaskValues } | { ok: false; errors: TaskDraftErrors }

/** Doğrulanmış, kaydedilmeye hazır değerler (create ve update ortak). */
export interface TaskValues {
  kind: TaskKind
  title: string
  notes: string | null
  subjectId: string | null
  dueDate: ISODate | null
  recurrence: Task['recurrence']
  targetQuantity: number | null
  quantityUnit: string | null
}

const numberFormat = new Intl.NumberFormat('tr-TR')

const MESSAGES = {
  titleRequired: 'Başlık gerekli',
  titleTooLong: `Başlık en fazla ${numberFormat.format(TITLE_MAX_LENGTH)} karakter olabilir`,
  notesTooLong: `Not en fazla ${numberFormat.format(NOTES_MAX_LENGTH)} karakter olabilir`,
  weekdaysRequired: 'En az bir gün seç',
  dueDateRequired: 'Son tarih gerekli',
  dueDateInvalid: 'Geçerli bir tarih gir',
  quantityInvalid: 'Pozitif bir tam sayı gir',
  quantityTooLarge: `En fazla ${numberFormat.format(QUANTITY_MAX)} olabilir`,
  unitTooLong: `Birim en fazla ${numberFormat.format(UNIT_MAX_LENGTH)} karakter olabilir`,
} as const

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/
/** Yalnızca rakam ya da Türkçe binlik ayraçlı ('1.000') tam sayı. */
const INTEGER_PATTERN = /^(\d+|\d{1,3}(\.\d{3})+)$/

/** Yeni görev için boş taslak. Ödevin varsayılan son tarihi `today`; rutin varsayılanı daily. */
export function emptyDraft(kind: TaskKind, today: ISODate): TaskDraft {
  return {
    kind,
    title: '',
    notes: '',
    subjectId: '',
    frequency: 'daily',
    weekdays: [],
    // Rutinde yok sayılır; formda tür değiştirilirse ödev için hazır bir varsayılan olur.
    dueDate: today,
    targetQuantity: '',
    quantityUnit: '',
  }
}

/** Var olan görevden düzenleme taslağı. */
export function draftFromTask(task: Task): TaskDraft {
  const targetQuantity = task.targetQuantity ?? null
  return {
    kind: task.kind,
    title: task.title,
    notes: task.notes ?? '',
    subjectId: task.subjectId ?? '',
    frequency: task.recurrence?.frequency ?? 'daily',
    weekdays: normalizeWeekdays(task.recurrence?.weekdays ?? []),
    dueDate: task.dueDate ?? '',
    targetQuantity: targetQuantity === null ? '' : String(targetQuantity),
    quantityUnit: task.quantityUnit ?? '',
  }
}

/**
 * Taslağı doğrular ve normalize eder (trim, boş → null, weekdays sıralı/tekil, daily → weekdays []).
 * Hatalar: başlık boş/uzun, weekly + gün yok, ödev + son tarih yok/geçersiz, miktar tam sayı değil /
 * ≤0 / > QUANTITY_MAX, birim uzun, not uzun. Rutinde dueDate null; ödevde recurrence null.
 */
export function validateDraft(draft: TaskDraft): DraftValidation {
  const errors: TaskDraftErrors = {}
  const isRoutine = draft.kind === 'routine'

  const title = draft.title.trim()
  if (title === '') errors.title = MESSAGES.titleRequired
  else if (title.length > TITLE_MAX_LENGTH) errors.title = MESSAGES.titleTooLong

  const notes = draft.notes.trim()
  if (notes.length > NOTES_MAX_LENGTH) errors.notes = MESSAGES.notesTooLong

  const weekdays = draft.frequency === 'weekly' ? normalizeWeekdays(draft.weekdays) : []
  if (isRoutine && draft.frequency === 'weekly' && weekdays.length === 0) {
    errors.weekdays = MESSAGES.weekdaysRequired
  }

  const dueDate = draft.dueDate.trim()
  if (!isRoutine) {
    if (dueDate === '') errors.dueDate = MESSAGES.dueDateRequired
    else if (!isValidISODate(dueDate)) errors.dueDate = MESSAGES.dueDateInvalid
  }

  const quantityError = quantityErrorFor(draft.targetQuantity)
  if (quantityError) errors.targetQuantity = quantityError

  const unit = draft.quantityUnit.trim()
  if (unit.length > UNIT_MAX_LENGTH) errors.quantityUnit = MESSAGES.unitTooLong

  if (Object.keys(errors).length > 0) return { ok: false, errors }

  const targetQuantity = parseQuantity(draft.targetQuantity) ?? null
  const subjectId = draft.subjectId.trim()
  return {
    ok: true,
    value: {
      kind: draft.kind,
      title,
      notes: notes === '' ? null : notes,
      subjectId: subjectId === '' ? null : subjectId,
      dueDate: isRoutine ? null : dueDate,
      recurrence: isRoutine ? { frequency: draft.frequency, weekdays } : null,
      targetQuantity,
      quantityUnit: unit === '' ? null : unit,
    },
  }
}

/** Kullanıcı girdisi miktar ('' / boşluk → null). Geçersizse (tam sayı değil, ≤0, > max) undefined. */
export function parseQuantity(input: string): number | null | undefined {
  const trimmed = input.trim()
  if (trimmed === '') return null
  if (!INTEGER_PATTERN.test(trimmed)) return undefined
  const value = Number(trimmed.replaceAll('.', ''))
  if (!Number.isSafeInteger(value) || value <= 0 || value > QUANTITY_MAX) return undefined
  return value
}

/** TaskValues → yeni Task girdisi. Rutinde startDate = today (ödevde null); completedAt null. */
export function newTaskInput(values: TaskValues, today: ISODate, order: number): NewEntity<Task> {
  return {
    title: values.title,
    kind: values.kind,
    notes: values.notes,
    subjectId: values.subjectId,
    dueDate: values.dueDate,
    recurrence: copyRecurrence(values.recurrence),
    completedAt: null,
    order,
    startDate: values.kind === 'routine' ? today : null,
    targetQuantity: values.targetQuantity,
    quantityUnit: values.quantityUnit,
    completedQuantity: null,
  }
}

/** TaskValues → güncelleme yaması (kind ve startDate değişmez). */
export function taskPatch(values: TaskValues): EntityPatch<Task> {
  return {
    title: values.title,
    notes: values.notes,
    subjectId: values.subjectId,
    dueDate: values.dueDate,
    recurrence: copyRecurrence(values.recurrence),
    targetQuantity: values.targetQuantity,
    quantityUnit: values.quantityUnit,
  }
}

// --- Repository eylemleri ---------------------------------------------------------------

/** Yeni görev oluşturur; order = mevcut (silinmemiş) görevlerin max order + 1 (yoksa 0). */
export async function createTask(
  repos: Repositories,
  values: TaskValues,
  today: ISODate,
): Promise<Task> {
  const tasks = await repos.tasks.findAll()
  const order = tasks.reduce((max, task) => Math.max(max, task.order + 1), 0)
  return repos.tasks.create(newTaskInput(values, today, order))
}

export async function updateTask(
  repos: Repositories,
  id: string,
  values: TaskValues,
): Promise<Task> {
  return repos.tasks.update(id, taskPatch(values))
}

/** Görevi ve (rutinse) tüm tamamlamalarını soft-delete eder. */
export async function deleteTask(repos: Repositories, task: Task): Promise<void> {
  const completions = await repos.taskCompletions.findByTask(task.id)
  for (const completion of completions) {
    await repos.taskCompletions.delete(completion.id)
  }
  await repos.tasks.delete(task.id)
}

/**
 * Tek dokunuşla tamamla/geri al (`day` için).
 * - routine: o güne ait silinmemiş tamamlama varsa HEPSİNİ soft-delete (geri al); yoksa
 *   { taskId, date: day, completedAt: now, quantity } oluştur.
 * - assignment: completedAt doluysa completedAt = null, completedQuantity = null; değilse
 *   completedAt = now, completedQuantity = quantity.
 * `quantity` verilmezse null. Dönüş: işlem sonrası tamamlanmış mı.
 */
export async function toggleCompletion(
  repos: Repositories,
  task: Task,
  day: ISODate,
  now: Date,
  quantity: number | null = null,
): Promise<boolean> {
  if (task.kind === 'routine') {
    const existing = await completionsOn(repos, task.id, day)
    if (existing.length > 0) {
      for (const completion of existing) {
        await repos.taskCompletions.delete(completion.id)
      }
      return false
    }
    await repos.taskCompletions.create({
      taskId: task.id,
      date: day,
      completedAt: toISODateTime(now),
      quantity,
    })
    return true
  }

  const current = await currentTask(repos, task)
  if (current.completedAt !== null) {
    await repos.tasks.update(task.id, { completedAt: null, completedQuantity: null })
    return false
  }
  await repos.tasks.update(task.id, {
    completedAt: toISODateTime(now),
    completedQuantity: quantity,
  })
  return true
}

/**
 * Gerçekleşen miktarı kaydeder ve görevi tamamlanmış yapar (zaten tamamlanmışsa yalnızca miktarı
 * günceller). routine: o günün tamamlaması (yoksa oluşturulur); assignment: completedQuantity
 * (+ completedAt yoksa now).
 */
export async function recordQuantity(
  repos: Repositories,
  task: Task,
  day: ISODate,
  now: Date,
  quantity: number | null,
): Promise<void> {
  if (task.kind === 'routine') {
    const [first] = await completionsOn(repos, task.id, day)
    if (first) {
      await repos.taskCompletions.update(first.id, { quantity })
      return
    }
    await repos.taskCompletions.create({
      taskId: task.id,
      date: day,
      completedAt: toISODateTime(now),
      quantity,
    })
    return
  }

  const current = await currentTask(repos, task)
  await repos.tasks.update(task.id, {
    completedAt: current.completedAt ?? toISODateTime(now),
    completedQuantity: quantity,
  })
}

// --- Yardımcılar ------------------------------------------------------------------------

function isWeekday(value: number): value is Weekday {
  return Number.isInteger(value) && value >= 1 && value <= 7
}

/** Geçerli (1…7), tekil ve artan sıralı yeni dizi. */
function normalizeWeekdays(weekdays: readonly number[]): Weekday[] {
  return [...new Set(weekdays)].filter(isWeekday).sort((a, b) => a - b)
}

function copyRecurrence(recurrence: Task['recurrence']): Task['recurrence'] {
  return recurrence === null
    ? null
    : { frequency: recurrence.frequency, weekdays: [...recurrence.weekdays] }
}

/** 'YYYY-MM-DD' biçiminde ve gerçek bir takvim günü mü (ör. 2026-02-30 değil). */
function isValidISODate(value: string): boolean {
  if (!ISO_DATE_PATTERN.test(value)) return false
  const year = Number(value.slice(0, 4))
  const month = Number(value.slice(5, 7))
  const day = Number(value.slice(8, 10))
  const date = new Date(Date.UTC(year, month - 1, day))
  return (
    date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
  )
}

function quantityErrorFor(input: string): string | undefined {
  if (parseQuantity(input) !== undefined) return undefined
  const trimmed = input.trim()
  const isPositiveInteger = INTEGER_PATTERN.test(trimmed) && Number(trimmed.replaceAll('.', '')) > 0
  return isPositiveInteger ? MESSAGES.quantityTooLarge : MESSAGES.quantityInvalid
}

/** Görevin `day` günündeki silinmemiş tamamlamaları, en eskisi önce. */
async function completionsOn(
  repos: Repositories,
  taskId: string,
  day: ISODate,
): Promise<TaskCompletion[]> {
  const completions = await repos.taskCompletions.findByTask(taskId)
  return completions
    .filter((completion) => completion.date === day && completion.deletedAt === null)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
}

/** Bayat UI kopyasına karşı görevin güncel halini okur (bulunamazsa verilen kopya). */
async function currentTask(repos: Repositories, task: Task): Promise<Task> {
  return (await repos.tasks.findById(task.id)) ?? task
}
