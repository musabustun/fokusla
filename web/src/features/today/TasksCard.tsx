import { CircleCheck } from 'lucide-react'
import { useState } from 'react'
import { ROUTES } from '@/app/routes'
import { useServices } from '@/data'
import type { ISODate, UUID } from '@/domain'
import { planTaskToggle, todayTaskOverview, type TodayTaskItem } from '@/domain/calc/today'
import { ProgressBar } from '@/ui'
import { formatInteger } from './format'
import { applyTaskToggle } from './taskActions'
import { TodayCard, CardEmpty } from './TodayCard'
import { TodayTaskRow } from './TodayTaskRow'
import { useTodayTasksData, type TodayTasksData } from './useTodayData'

export interface TasksCardProps {
  today: ISODate
  className?: string
}

/** Kartta gösterilen en fazla görev; fazlası için "+N görev daha" + "Tümü" bağlantısı. */
const TODAY_TASK_LIMIT = 6

const TOGGLE_ERROR_MESSAGE = 'Görev güncellenemedi. Tekrar dene.'

interface TaskToggleState {
  pendingIds: ReadonlySet<UUID>
  error: string | null
  toggle: (item: TodayTaskItem) => Promise<void>
}

/** Tamamla/geri al: planı uygular; bekleyen görevleri ve son hatayı tutar. */
function useTaskToggle(data: TodayTasksData | undefined, today: ISODate): TaskToggleState {
  const { repositories } = useServices()
  const [pendingIds, setPendingIds] = useState<ReadonlySet<UUID>>(new Set())
  const [error, setError] = useState<string | null>(null)

  const toggle = async (item: TodayTaskItem) => {
    if (!data) return
    const id = item.task.id
    setError(null)
    setPendingIds((current) => new Set([...current, id]))
    try {
      const plan = planTaskToggle(item.task, data.completions, today)
      await applyTaskToggle(repositories, plan, new Date())
    } catch (cause) {
      console.error('Bugün: görev güncellenemedi', cause)
      setError(TOGGLE_ERROR_MESSAGE)
    } finally {
      setPendingIds((current) => new Set([...current].filter((pendingId) => pendingId !== id)))
    }
  }

  return { pendingIds, error, toggle }
}

function ProgressHeader({ doneCount, totalCount }: { doneCount: number; totalCount: number }) {
  if (totalCount === 0) {
    return <p className="text-subheadline text-secondary-label">Bugün yapılacak görev yok.</p>
  }
  const isAllDone = doneCount === totalCount
  return (
    <div className="flex flex-col gap-2">
      <p className="text-subheadline text-secondary-label tabular-nums">
        {formatInteger(doneCount)} / {formatInteger(totalCount)} tamamlandı
      </p>
      <ProgressBar
        value={doneCount / totalCount}
        label="Bugünün görevleri ilerlemesi"
        tone={isAllDone ? 'success' : 'accent'}
        size="small"
      />
      {isAllDone && (
        <p className="flex items-center gap-1.5 text-subheadline font-semibold text-success">
          <CircleCheck aria-hidden className="size-4 shrink-0" strokeWidth={2.5} />
          Bugünlük hepsi tamam!
        </p>
      )}
    </div>
  )
}

/** Bugün kartı: günün görevleri, ilerleme ve tek dokunuşla tamamla/geri al. */
export function TasksCard({ today, className }: TasksCardProps) {
  const data = useTodayTasksData(today)
  const { pendingIds, error, toggle } = useTaskToggle(data, today)
  const overview = data ? todayTaskOverview(data.tasks, data.completions, today) : undefined
  const hasItems = (overview?.items.length ?? 0) > 0

  const renderBody = () => {
    if (!overview) return <div aria-hidden className="min-h-11" />
    if (overview.items.length === 0) {
      return (
        <CardEmpty message="Bugün için görev yok." actionLabel="Görev ekle" to={ROUTES.tasks} />
      )
    }
    const visible = overview.items.slice(0, TODAY_TASK_LIMIT)
    const hiddenCount = overview.items.length - visible.length
    return (
      <div className="flex flex-col gap-2">
        <ProgressHeader doneCount={overview.doneCount} totalCount={overview.totalCount} />
        <ul className="flex flex-col">
          {visible.map((item) => (
            <TodayTaskRow
              key={item.task.id}
              item={item}
              today={today}
              pending={pendingIds.has(item.task.id)}
              onToggle={(target) => void toggle(target)}
            />
          ))}
        </ul>
        {hiddenCount > 0 && (
          <p className="text-footnote text-secondary-label">
            +{formatInteger(hiddenCount)} görev daha
          </p>
        )}
        {error && (
          <p role="alert" className="text-footnote text-danger">
            {error}
          </p>
        )}
      </div>
    )
  }

  return (
    <TodayCard
      title="Bugünün görevleri"
      // Boş durumda tek sonraki adım "Görev ekle"dir; "Tümü" yalnızca liste varken gösterilir.
      linkTo={hasItems ? ROUTES.tasks : undefined}
      linkLabel="Tüm görevler"
      className={className}
    >
      {renderBody()}
    </TodayCard>
  )
}
