import { useServices } from '@/data'
import type { ISODate } from '@/domain'
import { Button, Sheet } from '@/ui'
import type { SubjectGroup } from './subjectOptions'
import { TaskFormFields } from './TaskForm'
import { createTask, emptyDraft } from './taskModel'
import { useTaskForm } from './useTaskForm'

const FORM_ID = 'task-create-form'

export interface AddTaskSheetProps {
  open: boolean
  today: ISODate
  subjectGroups: readonly SubjectGroup[]
  onClose: () => void
}

interface AddTaskFormProps {
  today: ISODate
  subjectGroups: readonly SubjectGroup[]
  onClose: () => void
}

function AddTaskContent({ today, subjectGroups, onClose }: AddTaskFormProps) {
  const { repositories } = useServices()
  const form = useTaskForm({
    initialDraft: emptyDraft('routine', today),
    onSubmit: async (values) => {
      await createTask(repositories, values, today)
      onClose()
    },
  })
  return (
    <Sheet
      open
      onClose={onClose}
      title="Yeni görev"
      footer={
        <Button type="submit" form={FORM_ID} fullWidth size="large" loading={form.saving}>
          Kaydet
        </Button>
      }
    >
      <TaskFormFields id={FORM_ID} form={form} subjectGroups={subjectGroups} today={today} />
    </Sheet>
  )
}

/** "Yeni görev" sayfası. Her açılışta form sıfırdan başlar. */
export function AddTaskSheet({ open, ...rest }: AddTaskSheetProps) {
  if (!open) return null
  return <AddTaskContent {...rest} />
}
