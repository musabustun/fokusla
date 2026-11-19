import { describe, expect, it } from 'vitest'
import type { Task } from '@/domain'
import type { RowContext } from './rowModel'
import { allView, todayView } from './views'

const TODAY = '2026-11-19'
const CTX: RowContext = { completions: [], today: TODAY, subjectsById: new Map() }

let counter = 0
function task(partial: Partial<Task> & Pick<Task, 'title'>): Task {
  counter += 1
  return {
    id: `t${counter}`,
    kind: 'assignment',
    notes: null,
    subjectId: null,
    dueDate: null,
    recurrence: null,
    completedAt: null,
    order: 0,
    startDate: null,
    createdAt: '2026-11-01T08:00:00.000Z',
    updatedAt: '2026-11-01T08:00:00.000Z',
    deletedAt: null,
    ...partial,
  }
}

const titles = (result: ReturnType<typeof allView>) =>
  result.sections.map((section) => [section.title, section.rows.map((row) => row.task.title)])

describe('allView', () => {
  const tasks = [
    task({ title: 'Çay', dueDate: '2026-11-25', order: 2 }),
    task({ title: 'Bal', dueDate: '2026-11-25', order: 2 }),
    task({ title: 'Ayva', dueDate: '2026-11-20', order: 5 }),
    task({ title: 'Tarihsiz', dueDate: null, order: 0 }),
    task({ title: 'Eski', dueDate: '2026-11-01', completedAt: '2026-11-02T08:00:00.000Z' }),
    task({ title: 'Yeni', dueDate: '2026-11-10', completedAt: '2026-11-12T08:00:00.000Z' }),
    task({ title: 'Silinmiş', dueDate: '2026-11-20', deletedAt: '2026-11-03T08:00:00.000Z' }),
    task({
      title: 'Rutin B',
      kind: 'routine',
      order: 1,
      recurrence: { frequency: 'daily', weekdays: [] },
    }),
    task({
      title: 'Rutin A',
      kind: 'routine',
      order: 1,
      recurrence: { frequency: 'daily', weekdays: [] },
    }),
  ]

  it('rutinleri sıraya, ödevleri son tarihe, tamamlananları en yeni önce dizer', () => {
    expect(titles(allView(tasks, CTX, false))).toEqual([
      ['Rutinler', ['Rutin A', 'Rutin B']],
      ['Ödevler', ['Ayva', 'Bal', 'Çay', 'Tarihsiz']],
      ['Tamamlanan ödevler', ['Yeni', 'Eski']],
    ])
  })

  it('gizlemede tamamlanan ödevleri çıkarır; görev yoksa hasTasks false', () => {
    expect(titles(allView(tasks, CTX, true))).toEqual([
      ['Rutinler', ['Rutin A', 'Rutin B']],
      ['Ödevler', ['Ayva', 'Bal', 'Çay', 'Tarihsiz']],
    ])
    expect(allView([], CTX, false)).toEqual({ sections: [], hasTasks: false })
  })
})

describe('todayView', () => {
  it('boş bölümleri çıkarır ve gizlemede tamamlananları süzer', () => {
    const tasks = [
      task({ title: 'Açık', dueDate: TODAY }),
      task({ title: 'Bitti', dueDate: TODAY, completedAt: '2026-11-19T07:00:00.000Z' }),
    ]
    expect(titles(todayView(tasks, CTX, false))).toEqual([['Bugün teslim', ['Açık', 'Bitti']]])
    const hidden = todayView(tasks, CTX, true)
    expect(titles(hidden)).toEqual([['Bugün teslim', ['Açık']]])
    expect(hidden.hasTasks).toBe(true)
  })
})
