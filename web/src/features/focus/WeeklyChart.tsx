import type { DailyFocusTotal } from '@/domain/calc/focus'
import { cx } from '@/ui'
import { formatDayLabel, formatWeekdayShort } from './formatDate'
import { formatDurationText } from './formatDuration'

export interface WeeklyChartProps {
  /** Eskiden yeniye günler; son eleman bugün. */
  totals: readonly DailyFocusTotal[]
}

/** Sıfır olmayan günlerde çubuk görünür kalsın diye en küçük yükseklik (%). */
const MIN_BAR_PERCENT = 4

function barPercent(focusMs: number, maxMs: number): number {
  if (focusMs <= 0 || maxMs <= 0) return 0
  return Math.max(MIN_BAR_PERCENT, (focusMs / maxMs) * 100)
}

/** Son günlerin odak süreleri: görsel çubuklar + ekran okuyucu için metin. */
export function WeeklyChart({ totals }: WeeklyChartProps) {
  const maxMs = Math.max(0, ...totals.map((total) => total.focusMs))
  const lastIndex = totals.length - 1
  return (
    <ul role="list" aria-label="Son 7 gün" className="flex h-36 items-stretch gap-2">
      {totals.map((total, index) => {
        const isToday = index === lastIndex
        return (
          <li key={total.day} className="flex min-w-0 flex-1 flex-col items-center gap-1.5">
            <div aria-hidden className="flex w-full flex-1 items-end rounded-sm bg-fill">
              <div
                className="w-full rounded-sm bg-accent motion-safe:transition-[height]"
                style={{ height: `${barPercent(total.focusMs, maxMs)}%` }}
              />
            </div>
            <span
              aria-hidden
              className={cx(
                'text-caption',
                isToday ? 'font-semibold text-label' : 'text-secondary-label',
              )}
            >
              {formatWeekdayShort(total.day)}
            </span>
            <span className="sr-only">
              {`${formatDayLabel(total.day)}: ${formatDurationText(total.focusMs)}`}
            </span>
          </li>
        )
      })}
    </ul>
  )
}
