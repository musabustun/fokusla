import { Check, CircleAlert } from 'lucide-react'
import { useId } from 'react'
import type { ISODate } from '@/domain'
import { daysUntilDue } from '@/domain/calc/tasks'
import type { TodayTaskItem } from '@/domain/calc/today'
import { cx } from '@/ui'
import { formatInteger } from './format'

/** Satırın kısa alt başlığı (gruba göre): "Gecikti · 3 gün", "Rutin", "Bugün teslim", "Yarın"… */
function taskSubtitle(item: TodayTaskItem, today: ISODate): string {
  const days = daysUntilDue(item.task, today)
  switch (item.group) {
    case 'routine':
      return 'Rutin'
    case 'overdue':
      return `Gecikti · ${formatInteger(Math.abs(days ?? 0))} gün`
    case 'dueToday':
      return item.task.dueDate === null ? 'Tarihsiz' : 'Bugün teslim'
    case 'upcoming':
      return days === 1 ? 'Yarın' : `${formatInteger(days ?? 0)} gün sonra`
  }
}

export interface TodayTaskRowProps {
  item: TodayTaskItem
  today: ISODate
  pending: boolean
  onToggle: (item: TodayTaskItem) => void
}

/**
 * Bugün kartındaki görev satırı: yuvarlak onay kutusu (Görevler modülündekiyle aynı görünüm ve
 * erişilebilir ad = görev başlığı) + başlık + kısa alt başlık.
 */
export function TodayTaskRow({ item, today, pending, onToggle }: TodayTaskRowProps) {
  const subtitleId = useId()
  const { task, done } = item
  // Tamamlanmış görevde gecikme artık uyarı değildir; yalnızca açık gecikenler vurgulanır.
  const isAlert = item.group === 'overdue' && !done
  return (
    <li className="relative flex items-center gap-1 before:absolute before:top-0 before:right-0 before:left-12 before:h-px before:bg-separator first:before:hidden">
      <button
        type="button"
        role="checkbox"
        aria-checked={done}
        aria-label={task.title}
        aria-describedby={subtitleId}
        // `disabled` yerine aria-disabled: yazma sürerken klavye odağı düğmede kalsın.
        aria-disabled={pending || undefined}
        onClick={() => {
          if (!pending) onToggle(item)
        }}
        className="group -ml-2 flex size-11 shrink-0 items-center justify-center rounded-full aria-disabled:cursor-progress aria-disabled:opacity-40"
      >
        <span
          aria-hidden
          className={cx(
            'flex size-6 items-center justify-center rounded-full border-2 motion-safe:transition-colors',
            done ? 'border-success bg-success text-success-contrast' : 'border-separator-strong',
          )}
        >
          {done && <Check className="size-4" strokeWidth={3} />}
        </span>
      </button>
      <div className="flex min-w-0 flex-1 flex-col py-2">
        <span
          className={cx(
            'text-body break-words',
            done ? 'text-secondary-label line-through' : 'text-label',
          )}
        >
          {task.title}
        </span>
        <span
          id={subtitleId}
          className={cx(
            'inline-flex items-center gap-1 text-subheadline',
            isAlert ? 'font-semibold text-danger' : 'text-secondary-label',
          )}
        >
          {isAlert && <CircleAlert aria-hidden className="size-3.5 shrink-0" strokeWidth={2.5} />}
          {taskSubtitle(item, today)}
        </span>
      </div>
    </li>
  )
}
