import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { Repositories } from '@/data'
import { toISODateTime, type Task } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { applyTaskToggle } from './taskActions'

const TODAY = '2026-11-19'
const NOW = new Date(2026, 10, 19, 10, 0, 0)

function createRoutine(repos: Repositories): Promise<Task> {
  return repos.tasks.create({
    title: 'Paragraf',
    kind: 'routine',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: { frequency: 'daily', weekdays: [] },
    completedAt: null,
    order: 0,
    startDate: TODAY,
  })
}

function createAssignment(repos: Repositories, completedAt: string | null = null): Promise<Task> {
  return repos.tasks.create({
    title: 'Fizik ödevi',
    kind: 'assignment',
    notes: null,
    subjectId: null,
    dueDate: TODAY,
    recurrence: null,
    completedAt,
    order: 0,
    completedQuantity: completedAt === null ? null : 12,
  })
}

describe('applyTaskToggle', () => {
  let ctx: TestServices
  let repos: Repositories

  beforeEach(() => {
    ctx = createTestServices()
    repos = ctx.services.repositories
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('createCompletion: o güne miktarsız bir tamamlama oluşturur', async () => {
    const task = await createRoutine(repos)

    await applyTaskToggle(repos, { kind: 'createCompletion', taskId: task.id, date: TODAY }, NOW)

    const completions = await repos.taskCompletions.findByDate(TODAY)
    expect(completions).toHaveLength(1)
    expect(completions[0]).toMatchObject({
      taskId: task.id,
      date: TODAY,
      completedAt: toISODateTime(NOW),
      quantity: null,
    })
  })

  it('deleteCompletions: listelenen her tamamlamayı soft-delete eder', async () => {
    const task = await createRoutine(repos)
    const base = { taskId: task.id, date: TODAY, completedAt: toISODateTime(NOW), quantity: null }
    const first = await repos.taskCompletions.create(base)
    const second = await repos.taskCompletions.create(base)

    await applyTaskToggle(
      repos,
      { kind: 'deleteCompletions', completionIds: [first.id, second.id] },
      NOW,
    )

    expect(await repos.taskCompletions.findByDate(TODAY)).toEqual([])
    const all = await repos.taskCompletions.findAll({ includeDeleted: true })
    expect(all.every((c) => c.deletedAt !== null)).toBe(true)
  })

  it('setAssignmentCompleted (true): completedAt = now, completedQuantity = null', async () => {
    const task = await createAssignment(repos)

    await applyTaskToggle(
      repos,
      { kind: 'setAssignmentCompleted', taskId: task.id, completed: true },
      NOW,
    )

    expect(await repos.tasks.findById(task.id)).toMatchObject({
      completedAt: toISODateTime(NOW),
      completedQuantity: null,
    })
  })

  it('setAssignmentCompleted (false): completedAt ve completedQuantity temizlenir', async () => {
    const task = await createAssignment(repos, '2026-11-19T07:00:00.000Z')

    await applyTaskToggle(
      repos,
      { kind: 'setAssignmentCompleted', taskId: task.id, completed: false },
      NOW,
    )

    expect(await repos.tasks.findById(task.id)).toMatchObject({
      completedAt: null,
      completedQuantity: null,
    })
  })

  it('none: hiçbir şey yazmaz', async () => {
    const task = await createAssignment(repos)

    await applyTaskToggle(repos, { kind: 'none' }, NOW)

    expect(await repos.tasks.findById(task.id)).toEqual(task)
    expect(await repos.taskCompletions.findAll({ includeDeleted: true })).toEqual([])
  })

  it('repository hatası yukarı iletilir', async () => {
    await expect(
      applyTaskToggle(
        repos,
        { kind: 'setAssignmentCompleted', taskId: crypto.randomUUID(), completed: true },
        NOW,
      ),
    ).rejects.toThrow()
  })
})
