/** Görevler testlerinin ortak kurulumu (yalnızca testlerde kullanılır). */
import { render } from '@testing-library/react'
import { vi } from 'vitest'
import { ServicesProvider, type AppServices, type Repositories } from '@/data'
import type { Subject, Task } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { createTask, type TaskValues } from './taskModel'
import { TasksScreen } from './TasksScreen'

/** Perşembe, 19 Kasım 2026, 10:00 (yerel). */
export const NOW = new Date(2026, 10, 19, 10, 0, 0)
export const TODAY = '2026-11-19'

export async function setupServices(): Promise<TestServices> {
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(NOW)
  localStorage.clear()
  const ctx = createTestServices()
  await ctx.services.repositories.profiles.create({
    displayName: null,
    field: 'SAY',
    appleUserId: null,
    targetExamYear: null,
    onboardingCompletedAt: '2026-11-01T08:00:00.000Z',
  })
  return ctx
}

export async function teardownServices(ctx: TestServices) {
  vi.useRealTimers()
  await ctx.dispose()
}

type SubjectInput = Pick<Subject, 'name' | 'exam' | 'fields' | 'order'>

export async function seedSubjects(repos: Repositories): Promise<Record<string, Subject>> {
  const inputs: SubjectInput[] = [
    { name: 'Türkçe', exam: 'TYT', fields: ['SAY', 'EA', 'SOZ', 'DIL'], order: 0 },
    { name: 'Fizik', exam: 'AYT', fields: ['SAY'], order: 1 },
    { name: 'Tarih', exam: 'AYT', fields: ['SOZ', 'EA'], order: 2 },
  ]
  const created = await Promise.all(
    inputs.map((input) => repos.subjects.create({ ...input, catalogKey: null })),
  )
  return Object.fromEntries(created.map((subject) => [subject.name, subject]))
}

export function values(partial: Partial<TaskValues> & Pick<TaskValues, 'title'>): TaskValues {
  return {
    kind: 'routine',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: { frequency: 'daily', weekdays: [] },
    targetQuantity: null,
    quantityUnit: null,
    ...partial,
  }
}

export function assignment(title: string, dueDate: string, extra: Partial<TaskValues> = {}) {
  return values({ title, kind: 'assignment', dueDate, recurrence: null, ...extra })
}

export function seedTask(
  repos: Repositories,
  taskValues: TaskValues,
  today = TODAY,
): Promise<Task> {
  return createTask(repos, taskValues, today)
}

export function renderScreen(services: AppServices) {
  return render(
    <ServicesProvider services={services}>
      <TasksScreen />
    </ServicesProvider>,
  )
}
