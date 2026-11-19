import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { Repositories } from '@/data'
import type { Task, TaskCompletion } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import {
  NOTES_MAX_LENGTH,
  QUANTITY_MAX,
  TITLE_MAX_LENGTH,
  UNIT_MAX_LENGTH,
  createTask,
  deleteTask,
  draftFromTask,
  emptyDraft,
  newTaskInput,
  parseQuantity,
  recordQuantity,
  taskPatch,
  toggleCompletion,
  updateTask,
  validateDraft,
  type TaskDraft,
  type TaskValues,
} from './taskModel'

const TODAY = '2026-11-19'
const TOMORROW = '2026-11-20'
const NOW = new Date('2026-11-19T08:00:00.000Z')
const LATER = new Date('2026-11-19T12:30:00.000Z')

const BASE_TASK: Task = {
  id: 'task-1',
  createdAt: '2026-11-01T08:00:00.000Z',
  updatedAt: '2026-11-01T08:00:00.000Z',
  deletedAt: null,
  title: 'Paragraf',
  kind: 'routine',
  notes: null,
  subjectId: null,
  dueDate: null,
  recurrence: { frequency: 'daily', weekdays: [] },
  completedAt: null,
  order: 0,
}

function draft(overrides: Partial<TaskDraft> = {}): TaskDraft {
  return { ...emptyDraft('routine', TODAY), title: 'Paragraf', ...overrides }
}

function routineValues(overrides: Partial<TaskValues> = {}): TaskValues {
  return {
    kind: 'routine',
    title: 'Paragraf çöz',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: { frequency: 'daily', weekdays: [] },
    targetQuantity: 40,
    quantityUnit: 'soru',
    ...overrides,
  }
}

function assignmentValues(overrides: Partial<TaskValues> = {}): TaskValues {
  return {
    kind: 'assignment',
    title: 'Deneme analizi',
    notes: 'Yanlışları not al',
    subjectId: null,
    dueDate: TOMORROW,
    recurrence: null,
    targetQuantity: null,
    quantityUnit: null,
    ...overrides,
  }
}

describe('emptyDraft', () => {
  it.each(['routine', 'assignment'] as const)('%s için boş taslak döner', (kind) => {
    expect(emptyDraft(kind, TODAY)).toEqual({
      kind,
      title: '',
      notes: '',
      subjectId: '',
      frequency: 'daily',
      weekdays: [],
      dueDate: TODAY,
      targetQuantity: '',
      quantityUnit: '',
    })
  })
})

describe('draftFromTask', () => {
  it('rutini taslağa çevirir (günler sıralı, null → "")', () => {
    const task: Task = {
      ...BASE_TASK,
      notes: 'not',
      subjectId: 'subj-1',
      recurrence: { frequency: 'weekly', weekdays: [5, 1, 3] },
      targetQuantity: 50,
      quantityUnit: 'soru',
    }
    expect(draftFromTask(task)).toEqual({
      kind: 'routine',
      title: 'Paragraf',
      notes: 'not',
      subjectId: 'subj-1',
      frequency: 'weekly',
      weekdays: [1, 3, 5],
      dueDate: '',
      targetQuantity: '50',
      quantityUnit: 'soru',
    })
    expect(task.recurrence?.weekdays).toEqual([5, 1, 3])
  })

  it('opsiyonel alanları olmayan eski ödev kaydını taslağa çevirir', () => {
    const task: Task = { ...BASE_TASK, kind: 'assignment', recurrence: null, dueDate: TOMORROW }
    expect(draftFromTask(task)).toMatchObject({
      kind: 'assignment',
      frequency: 'daily',
      weekdays: [],
      dueDate: TOMORROW,
      notes: '',
      subjectId: '',
      targetQuantity: '',
      quantityUnit: '',
    })
  })
})

describe('parseQuantity', () => {
  it.each([
    ['', null],
    ['   ', null],
    ['1', 1],
    [' 42 ', 42],
    ['10000', 10_000],
    ['1.000', 1000],
    ['10.000', 10_000],
    ['0', undefined],
    ['-3', undefined],
    ['2.5', undefined],
    ['2,5', undefined],
    ['1e3', undefined],
    ['abc', undefined],
    ['10001', undefined],
    ['10.001', undefined],
  ])('%j → %j', (input, expected) => {
    expect(parseQuantity(input)).toBe(expected)
  })
})

describe('validateDraft', () => {
  it('rutini normalize eder (trim, boş → null, ödev alanları null)', () => {
    const result = validateDraft(
      draft({
        title: '  Paragraf  ',
        notes: '   ',
        subjectId: ' subj-1 ',
        dueDate: TODAY,
        targetQuantity: ' 40 ',
        quantityUnit: ' soru ',
      }),
    )
    expect(result).toEqual({
      ok: true,
      value: {
        kind: 'routine',
        title: 'Paragraf',
        notes: null,
        subjectId: 'subj-1',
        dueDate: null,
        recurrence: { frequency: 'daily', weekdays: [] },
        targetQuantity: 40,
        quantityUnit: 'soru',
      },
    })
  })

  it('daily rutinde seçili günleri yok sayar', () => {
    const result = validateDraft(draft({ frequency: 'daily', weekdays: [1, 2] }))
    expect(result.ok && result.value.recurrence).toEqual({ frequency: 'daily', weekdays: [] })
  })

  it('weekly rutinde günleri sıralar ve tekilleştirir, girdiyi değiştirmez', () => {
    const input = draft({ frequency: 'weekly', weekdays: [5, 1, 5, 3] })
    const result = validateDraft(input)
    expect(result.ok && result.value.recurrence).toEqual({
      frequency: 'weekly',
      weekdays: [1, 3, 5],
    })
    expect(input.weekdays).toEqual([5, 1, 5, 3])
  })

  it('ödevi normalize eder (recurrence null, not korunur)', () => {
    const result = validateDraft({
      ...emptyDraft('assignment', TODAY),
      title: 'Deneme',
      notes: ' Yanlışlar ',
      frequency: 'weekly',
      weekdays: [],
      dueDate: ` ${TOMORROW} `,
    })
    expect(result).toEqual({
      ok: true,
      value: {
        kind: 'assignment',
        title: 'Deneme',
        notes: 'Yanlışlar',
        subjectId: null,
        dueDate: TOMORROW,
        recurrence: null,
        targetQuantity: null,
        quantityUnit: null,
      },
    })
  })

  it('sınır uzunluklarını kabul eder', () => {
    const result = validateDraft(
      draft({
        title: 'a'.repeat(TITLE_MAX_LENGTH),
        notes: 'b'.repeat(NOTES_MAX_LENGTH),
        targetQuantity: String(QUANTITY_MAX),
        quantityUnit: 'c'.repeat(UNIT_MAX_LENGTH),
      }),
    )
    expect(result.ok).toBe(true)
  })

  it.each<[string, Partial<TaskDraft>, Record<string, string>]>([
    ['boş başlık', { title: '   ' }, { title: 'Başlık gerekli' }],
    [
      'uzun başlık',
      { title: 'a'.repeat(TITLE_MAX_LENGTH + 1) },
      { title: 'Başlık en fazla 120 karakter olabilir' },
    ],
    [
      'uzun not',
      { notes: 'a'.repeat(NOTES_MAX_LENGTH + 1) },
      { notes: 'Not en fazla 1.000 karakter olabilir' },
    ],
    ['weekly + gün yok', { frequency: 'weekly', weekdays: [] }, { weekdays: 'En az bir gün seç' }],
    ['ödev + son tarih yok', { kind: 'assignment', dueDate: '' }, { dueDate: 'Son tarih gerekli' }],
    [
      'ödev + biçimsiz tarih',
      { kind: 'assignment', dueDate: '19.11.2026' },
      { dueDate: 'Geçerli bir tarih gir' },
    ],
    [
      'ödev + olmayan gün',
      { kind: 'assignment', dueDate: '2026-02-30' },
      { dueDate: 'Geçerli bir tarih gir' },
    ],
    [
      'ödev + olmayan ay',
      { kind: 'assignment', dueDate: '2026-13-01' },
      { dueDate: 'Geçerli bir tarih gir' },
    ],
    ['miktar sıfır', { targetQuantity: '0' }, { targetQuantity: 'Pozitif bir tam sayı gir' }],
    ['miktar ondalık', { targetQuantity: '2,5' }, { targetQuantity: 'Pozitif bir tam sayı gir' }],
    ['miktar metin', { targetQuantity: 'çok' }, { targetQuantity: 'Pozitif bir tam sayı gir' }],
    ['miktar büyük', { targetQuantity: '10001' }, { targetQuantity: 'En fazla 10.000 olabilir' }],
    [
      'uzun birim',
      { quantityUnit: 'a'.repeat(UNIT_MAX_LENGTH + 1) },
      { quantityUnit: 'Birim en fazla 24 karakter olabilir' },
    ],
  ])('%s → hata', (_name, overrides, errors) => {
    expect(validateDraft(draft(overrides))).toEqual({ ok: false, errors })
  })

  it('rutinde geçersiz son tarih ve ödevde boş gün listesi hata değildir', () => {
    expect(validateDraft(draft({ dueDate: 'x' })).ok).toBe(true)
    expect(
      validateDraft(draft({ kind: 'assignment', dueDate: TODAY, frequency: 'weekly' })).ok,
    ).toBe(true)
  })

  it('birden çok hatayı birlikte döner', () => {
    const result = validateDraft(
      draft({ kind: 'assignment', title: '', dueDate: '', targetQuantity: '-1' }),
    )
    expect(result).toEqual({
      ok: false,
      errors: {
        title: 'Başlık gerekli',
        dueDate: 'Son tarih gerekli',
        targetQuantity: 'Pozitif bir tam sayı gir',
      },
    })
  })
})

describe('newTaskInput / taskPatch', () => {
  it('rutin için startDate = today ve tüm opsiyonel alanlar açıkça yazılır', () => {
    const values = routineValues({ recurrence: { frequency: 'weekly', weekdays: [1, 4] } })
    const input = newTaskInput(values, TODAY, 3)
    expect(input).toEqual({
      title: 'Paragraf çöz',
      kind: 'routine',
      notes: null,
      subjectId: null,
      dueDate: null,
      recurrence: { frequency: 'weekly', weekdays: [1, 4] },
      completedAt: null,
      order: 3,
      startDate: TODAY,
      targetQuantity: 40,
      quantityUnit: 'soru',
      completedQuantity: null,
    })
    expect(input.recurrence).not.toBe(values.recurrence)
  })

  it('ödev için startDate null', () => {
    expect(newTaskInput(assignmentValues(), TODAY, 0)).toMatchObject({
      kind: 'assignment',
      startDate: null,
      dueDate: TOMORROW,
      recurrence: null,
    })
  })

  it('yama kind ve startDate içermez', () => {
    const patch = taskPatch(routineValues())
    expect(patch).toEqual({
      title: 'Paragraf çöz',
      notes: null,
      subjectId: null,
      dueDate: null,
      recurrence: { frequency: 'daily', weekdays: [] },
      targetQuantity: 40,
      quantityUnit: 'soru',
    })
    expect(patch).not.toHaveProperty('kind')
    expect(patch).not.toHaveProperty('startDate')
  })
})

describe('repository eylemleri', () => {
  let ctx: TestServices
  let repos: Repositories

  beforeEach(() => {
    ctx = createTestServices()
    repos = ctx.services.repositories
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  async function activeCompletions(taskId: string): Promise<TaskCompletion[]> {
    return (await repos.taskCompletions.findByTask(taskId)).filter((c) => c.deletedAt === null)
  }

  describe('createTask', () => {
    it('order değerini silinmemiş görevlerin max + 1 olarak verir', async () => {
      const first = await createTask(repos, routineValues(), TODAY)
      const second = await createTask(repos, assignmentValues(), TODAY)
      expect(first.order).toBe(0)
      expect(second.order).toBe(1)

      await repos.tasks.delete(second.id)
      const third = await createTask(repos, routineValues({ title: 'Üçüncü' }), TODAY)
      expect(third.order).toBe(1)
    })

    it('rutinde startDate = today, ödevde null', async () => {
      const routine = await createTask(repos, routineValues(), TODAY)
      const assignment = await createTask(repos, assignmentValues(), TODAY)
      expect(routine).toMatchObject({
        startDate: TODAY,
        completedAt: null,
        completedQuantity: null,
      })
      expect(assignment).toMatchObject({ startDate: null, dueDate: TOMORROW })
      expect(await repos.tasks.findById(routine.id)).toEqual(routine)
    })
  })

  describe('updateTask', () => {
    it('alanları günceller, kind ve startDate değişmez', async () => {
      const task = await createTask(repos, routineValues(), '2026-11-01')
      const updated = await updateTask(
        repos,
        task.id,
        routineValues({
          kind: 'assignment',
          title: 'Yeni başlık',
          recurrence: { frequency: 'weekly', weekdays: [2] },
          targetQuantity: null,
          quantityUnit: null,
        }),
      )
      expect(updated).toMatchObject({
        kind: 'routine',
        startDate: '2026-11-01',
        title: 'Yeni başlık',
        recurrence: { frequency: 'weekly', weekdays: [2] },
        targetQuantity: null,
        quantityUnit: null,
        order: task.order,
      })
    })
  })

  describe('deleteTask', () => {
    it('görevi ve tamamlamalarını soft-delete eder', async () => {
      const task = await createTask(repos, routineValues(), TODAY)
      await toggleCompletion(repos, task, TODAY, NOW)
      await toggleCompletion(repos, task, TOMORROW, NOW)
      const other = await createTask(repos, routineValues({ title: 'Diğer' }), TODAY)
      await toggleCompletion(repos, other, TODAY, NOW)

      await deleteTask(repos, task)

      expect(await repos.tasks.findById(task.id)).toBeUndefined()
      expect((await repos.tasks.findById(task.id, { includeDeleted: true }))?.deletedAt).not.toBe(
        null,
      )
      expect(await activeCompletions(task.id)).toEqual([])
      const all = await repos.taskCompletions.findAll({ includeDeleted: true })
      expect(all.filter((c) => c.taskId === task.id)).toHaveLength(2)
      expect(all.filter((c) => c.taskId === task.id).every((c) => c.deletedAt !== null)).toBe(true)
      expect(await activeCompletions(other.id)).toHaveLength(1)
    })

    it('ödevi siler', async () => {
      const task = await createTask(repos, assignmentValues(), TODAY)
      await deleteTask(repos, task)
      expect(await repos.tasks.findAll()).toEqual([])
    })
  })

  describe('toggleCompletion — rutin', () => {
    it('aç / kapat / tekrar aç: geri almadan sonra yeni kayıt oluşturur', async () => {
      const task = await createTask(repos, routineValues(), TODAY)

      expect(await toggleCompletion(repos, task, TODAY, NOW)).toBe(true)
      const [first] = await activeCompletions(task.id)
      expect(first).toMatchObject({
        taskId: task.id,
        date: TODAY,
        completedAt: NOW.toISOString(),
        quantity: null,
      })

      expect(await toggleCompletion(repos, task, TODAY, LATER)).toBe(false)
      expect(await activeCompletions(task.id)).toEqual([])

      expect(await toggleCompletion(repos, task, TODAY, LATER, 12)).toBe(true)
      const [second] = await activeCompletions(task.id)
      expect(second?.id).not.toBe(first?.id)
      expect(second).toMatchObject({ completedAt: LATER.toISOString(), quantity: 12 })
    })

    it('geri almada o güne ait tüm kopyaları siler, diğer günlere dokunmaz', async () => {
      const task = await createTask(repos, routineValues(), TODAY)
      const completion = { taskId: task.id, date: TODAY, completedAt: NOW.toISOString() }
      await repos.taskCompletions.create({ ...completion, quantity: null })
      await repos.taskCompletions.create({ ...completion, quantity: 5 })
      await toggleCompletion(repos, task, TOMORROW, NOW)

      expect(await toggleCompletion(repos, task, TODAY, LATER)).toBe(false)
      const remaining = await activeCompletions(task.id)
      expect(remaining).toHaveLength(1)
      expect(remaining[0]?.date).toBe(TOMORROW)
    })
  })

  describe('toggleCompletion — ödev', () => {
    it('tamamlar ve geri alır', async () => {
      const task = await createTask(repos, assignmentValues(), TODAY)

      expect(await toggleCompletion(repos, task, TODAY, NOW, 30)).toBe(true)
      expect(await repos.tasks.findById(task.id)).toMatchObject({
        completedAt: NOW.toISOString(),
        completedQuantity: 30,
      })

      // Bayat kopya ile çağrılsa bile güncel durum esas alınır.
      expect(await toggleCompletion(repos, task, TODAY, LATER)).toBe(false)
      expect(await repos.tasks.findById(task.id)).toMatchObject({
        completedAt: null,
        completedQuantity: null,
      })

      expect(await toggleCompletion(repos, task, TODAY, LATER)).toBe(true)
      expect(await repos.tasks.findById(task.id)).toMatchObject({
        completedAt: LATER.toISOString(),
        completedQuantity: null,
      })
      expect(await repos.taskCompletions.findAll()).toEqual([])
    })
  })

  describe('recordQuantity', () => {
    it('rutin: tamamlama yoksa miktarla oluşturur, varsa yalnızca miktarı günceller', async () => {
      const task = await createTask(repos, routineValues(), TODAY)

      await recordQuantity(repos, task, TODAY, NOW, 25)
      const [created] = await activeCompletions(task.id)
      expect(created).toMatchObject({ date: TODAY, completedAt: NOW.toISOString(), quantity: 25 })

      await recordQuantity(repos, task, TODAY, LATER, 40)
      const after = await activeCompletions(task.id)
      expect(after).toHaveLength(1)
      expect(after[0]).toMatchObject({
        id: created?.id,
        completedAt: NOW.toISOString(),
        quantity: 40,
      })
    })

    it('ödev: tamamlanmamışsa completedAt = now, tamamlanmışsa yalnızca miktar', async () => {
      const task = await createTask(repos, assignmentValues(), TODAY)

      await recordQuantity(repos, task, TODAY, NOW, 10)
      expect(await repos.tasks.findById(task.id)).toMatchObject({
        completedAt: NOW.toISOString(),
        completedQuantity: 10,
      })

      await recordQuantity(repos, task, TODAY, LATER, null)
      expect(await repos.tasks.findById(task.id)).toMatchObject({
        completedAt: NOW.toISOString(),
        completedQuantity: null,
      })
    })

    it('silinmiş ödevde hata fırlatır', async () => {
      const task = await createTask(repos, assignmentValues(), TODAY)
      await repos.tasks.delete(task.id)
      await expect(recordQuantity(repos, task, TODAY, NOW, 1)).rejects.toThrow()
    })
  })
})
