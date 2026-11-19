import { CircleCheckBig, Eye, EyeOff, ListChecks, MousePointerClick, Plus } from 'lucide-react'
import { useState } from 'react'
import { useServices } from '@/data'
import {
  Button,
  Card,
  EmptyState,
  ScreenHeader,
  SegmentedControl,
  Sheet,
  type SegmentedOption,
} from '@/ui'
import { AddTaskSheet } from './AddTaskSheet'
import { formatDayTitle } from './format'
import type { RowContext, TaskRowModel } from './rowModel'
import { subjectGroups as buildSubjectGroups } from './subjectOptions'
import { TaskDetail } from './TaskDetail'
import { toggleCompletion } from './taskModel'
import { TaskSection } from './TaskSection'
import { useAsyncAction } from './useAsyncAction'
import { useHideCompleted } from './useHideCompleted'
import { useMediaQuery } from './useMediaQuery'
import { useTasksData } from './useTasksData'
import { useToday } from './useToday'
import { allView, todayView, type ViewResult } from './views'

type ViewMode = 'today' | 'all'

const VIEW_OPTIONS: readonly SegmentedOption<ViewMode>[] = [
  { value: 'today', label: 'Bugün' },
  { value: 'all', label: 'Tümü' },
]

/** iPad yatay ve üstü: liste + yan ayrıntı paneli. */
const WIDE_QUERY = '(min-width: 64rem)'

interface ViewEmptyProps {
  mode: ViewMode
  result: ViewResult
  onAdd: () => void
}

function ViewEmpty({ mode, result, onAdd }: ViewEmptyProps) {
  if (result.hasTasks) {
    return (
      <EmptyState
        icon={<CircleCheckBig />}
        title={mode === 'today' ? 'Bugünkü görevlerin tamam' : 'Açık görev kalmadı'}
        message="Tamamlananları görmek için “Tamamlananları göster”e dokun."
      />
    )
  }
  return (
    <EmptyState
      icon={<ListChecks />}
      title={mode === 'today' ? 'Bugün için görev yok' : 'Henüz görev yok'}
      message="Her gün tekrarlanan rutinlerini ve son tarihli ödevlerini ekle; tamamladıkça işaretle."
      action={
        <Button variant="tinted" icon={<Plus aria-hidden className="size-5" />} onClick={onAdd}>
          Yeni görev oluştur
        </Button>
      }
    />
  )
}

export function TasksScreen() {
  const { repositories } = useServices()
  const today = useToday()
  const isWide = useMediaQuery(WIDE_QUERY)
  const data = useTasksData()
  const [hideCompleted, setHideCompleted] = useHideCompleted()
  const [mode, setMode] = useState<ViewMode>('today')
  const [isAdding, setIsAdding] = useState(false)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const toggleAction = useAsyncAction()

  const ctx: RowContext = {
    completions: data.completions,
    today,
    subjectsById: data.subjectsById,
  }
  const result =
    mode === 'today'
      ? todayView(data.tasks, ctx, hideCompleted)
      : allView(data.tasks, ctx, hideCompleted)
  const selectedTask = data.tasks.find((task) => task.id === selectedId) ?? null
  const groups = buildSubjectGroups(data.subjects, data.field, selectedTask?.subjectId)

  const handleToggle = (model: TaskRowModel) =>
    void toggleAction.run(() => toggleCompletion(repositories, model.task, today, new Date()))
  const handleSelect = (model: TaskRowModel) => setSelectedId(model.task.id)
  const clearSelection = () => setSelectedId(null)

  const detail = selectedTask && (
    <TaskDetail
      key={selectedTask.id}
      task={selectedTask}
      ctx={ctx}
      subjectGroups={groups}
      showTitle={isWide}
      onDeleted={clearSelection}
    />
  )

  return (
    <>
      <ScreenHeader
        title="Görevler"
        subtitle={formatDayTitle(today)}
        actions={
          <Button
            variant="plain"
            aria-label="Görev ekle"
            icon={<Plus aria-hidden className="size-5" strokeWidth={2.5} />}
            onClick={() => setIsAdding(true)}
          >
            Ekle
          </Button>
        }
      />

      <div className="mb-6 flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
        <SegmentedControl
          aria-label="Görünüm"
          options={VIEW_OPTIONS}
          value={mode}
          onChange={setMode}
          className="min-w-44 flex-1 sm:flex-none"
        />
        <Button
          variant="plain"
          size="small"
          className="ml-auto"
          icon={
            hideCompleted ? (
              <Eye aria-hidden className="size-4" />
            ) : (
              <EyeOff aria-hidden className="size-4" />
            )
          }
          onClick={() => setHideCompleted(!hideCompleted)}
        >
          {hideCompleted ? 'Tamamlananları göster' : 'Tamamlananları gizle'}
        </Button>
      </div>

      {toggleAction.error && (
        <p
          role="alert"
          className="mb-4 rounded-md bg-danger-subtle px-4 py-3 text-subheadline text-danger"
        >
          {toggleAction.error}
        </p>
      )}

      <div className="lg:grid lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-start lg:gap-6">
        <div className="min-w-0">
          {data.isLoading ? (
            <p role="status" className="py-12 text-center text-subheadline text-secondary-label">
              Görevler yükleniyor…
            </p>
          ) : result.sections.length === 0 ? (
            <ViewEmpty mode={mode} result={result} onAdd={() => setIsAdding(true)} />
          ) : (
            result.sections.map((section) => (
              <TaskSection
                key={section.key}
                title={section.title}
                rows={section.rows}
                selectedId={isWide ? selectedId : null}
                onToggle={handleToggle}
                onSelect={handleSelect}
              />
            ))
          )}
        </div>

        {isWide && (
          <aside
            aria-label="Görev ayrıntıları"
            className="sticky top-6 max-h-[calc(100dvh-3rem)] overflow-y-auto rounded-lg"
          >
            <Card>
              {detail || (
                <div className="flex flex-col items-center gap-3 py-10 text-center">
                  <MousePointerClick aria-hidden className="size-8 text-tertiary-label" />
                  <p className="text-subheadline text-secondary-label">
                    Ayrıntıları görmek için bir görev seç
                  </p>
                </div>
              )}
            </Card>
          </aside>
        )}
      </div>

      {!isWide && (
        <Sheet
          open={selectedTask !== null}
          onClose={clearSelection}
          title={selectedTask?.title ?? ''}
        >
          {detail}
        </Sheet>
      )}

      <AddTaskSheet
        open={isAdding}
        today={today}
        subjectGroups={groups}
        onClose={() => setIsAdding(false)}
      />
    </>
  )
}
