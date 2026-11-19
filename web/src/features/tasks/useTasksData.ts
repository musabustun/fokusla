import { useMemo } from 'react'
import { useCurrentProfile, useLiveData, useServices } from '@/data'
import type { Subject, Task, TaskCompletion, YksField } from '@/domain'

export interface TasksData {
  /** Görevler ve tamamlamalar yüklenene kadar true. */
  isLoading: boolean
  tasks: Task[]
  completions: TaskCompletion[]
  subjects: Subject[]
  subjectsById: ReadonlyMap<string, Subject>
  /** Profil alanı (yoksa/yükleniyorsa undefined → tüm dersler). */
  field: YksField | undefined
}

const EMPTY_TASKS: Task[] = []
const EMPTY_COMPLETIONS: TaskCompletion[] = []
const EMPTY_SUBJECTS: Subject[] = []

/** Görevler ekranının canlı verileri (repository'ler üzerinden, Dexie'ye dokunmadan). */
export function useTasksData(): TasksData {
  const { repositories } = useServices()
  const tasks = useLiveData(() => repositories.tasks.findAll(), [repositories])
  const completions = useLiveData(() => repositories.taskCompletions.findAll(), [repositories])
  const subjects = useLiveData(() => repositories.subjects.findAll(), [repositories])
  const profileState = useCurrentProfile()

  const subjectList = subjects ?? EMPTY_SUBJECTS
  const subjectsById = useMemo(
    () => new Map(subjectList.map((subject) => [subject.id, subject])),
    [subjectList],
  )

  return {
    isLoading: tasks === undefined || completions === undefined,
    tasks: tasks ?? EMPTY_TASKS,
    completions: completions ?? EMPTY_COMPLETIONS,
    subjects: subjectList,
    subjectsById,
    field: profileState.status === 'ready' ? profileState.profile?.field : undefined,
  }
}
