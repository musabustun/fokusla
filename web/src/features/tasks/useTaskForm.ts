import { useState, type FormEvent } from 'react'
import type { TaskKind } from '@/domain'
import { validateDraft, type TaskDraft, type TaskDraftErrors, type TaskValues } from './taskModel'
import { useAsyncAction } from './useAsyncAction'

export interface UseTaskFormOptions {
  initialDraft: TaskDraft
  /** Doğrulanmış değerleri kaydeder; hata fırlatırsa form açık kalır ve hata gösterilir. */
  onSubmit: (values: TaskValues) => Promise<void>
}

export interface TaskFormState {
  draft: TaskDraft
  update: (patch: Partial<TaskDraft>) => void
  changeKind: (kind: TaskKind, today: string) => void
  /** Yalnızca ilk kaydetme denemesinden sonra dolar; sonra her değişiklikte yeniden hesaplanır. */
  errors: TaskDraftErrors
  saving: boolean
  submitError: string | null
  handleSubmit: (event: FormEvent<HTMLFormElement>) => void
}

const NO_ERRORS: TaskDraftErrors = {}

/** Görev formunun durumu (taslak + doğrulama + kaydetme). Alanlar `TaskFormFields`'ta çizilir. */
export function useTaskForm({ initialDraft, onSubmit }: UseTaskFormOptions): TaskFormState {
  const [draft, setDraft] = useState(initialDraft)
  const [attempted, setAttempted] = useState(false)
  const action = useAsyncAction()

  const validation = attempted ? validateDraft(draft) : null
  const errors = validation && !validation.ok ? validation.errors : NO_ERRORS

  const update = (patch: Partial<TaskDraft>) => setDraft((current) => ({ ...current, ...patch }))

  const changeKind = (kind: TaskKind, today: string) =>
    setDraft((current) => ({ ...current, kind, dueDate: current.dueDate || today }))

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (action.pending) return
    setAttempted(true)
    const result = validateDraft(draft)
    if (!result.ok) {
      focusFirstInvalid(event.currentTarget)
      return
    }
    void action.run(() => onSubmit(result.value))
  }

  return {
    draft,
    update,
    changeKind,
    errors,
    saving: action.pending,
    submitError: action.error,
    handleSubmit,
  }
}

/** Hatalı ilk alana odaklanır (React yeniden çizdikten sonra). */
function focusFirstInvalid(form: HTMLFormElement) {
  requestAnimationFrame(() => {
    form.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus()
  })
}
