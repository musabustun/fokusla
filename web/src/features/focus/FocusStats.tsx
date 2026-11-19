import type { DailyFocusTotal } from '@/domain/calc/focus'
import { Card } from '@/ui'
import { formatDurationText } from './formatDuration'
import { WeeklyChart } from './WeeklyChart'

export interface FocusStatsProps {
  averageFocusMs: number
  averageBreakMs: number
  todayTotalMs: number
  weeklyTotals: readonly DailyFocusTotal[]
}

function StatCard({
  title,
  valueMs,
  className,
}: {
  title: string
  valueMs: number
  className?: string
}) {
  return (
    <Card title={title} className={className}>
      <p className="text-title2 tabular-nums">{formatDurationText(valueMs)}</p>
    </Card>
  )
}

/** Odak istatistik kartları ve son 7 günün grafiği. */
export function FocusStats({
  averageFocusMs,
  averageBreakMs,
  todayTotalMs,
  weeklyTotals,
}: FocusStatsProps) {
  const weekTotalMs = weeklyTotals.reduce((sum, total) => sum + total.focusMs, 0)
  return (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3">
        <StatCard title="Bugün toplam" valueMs={todayTotalMs} className="col-span-2" />
        <StatCard title="Ortalama kesintisiz odak" valueMs={averageFocusMs} />
        <StatCard title="Ortalama mola" valueMs={averageBreakMs} />
      </div>
      <Card
        title="Son 7 gün"
        trailing={
          <span className="text-subheadline text-secondary-label tabular-nums">
            {formatDurationText(weekTotalMs)}
          </span>
        }
      >
        <WeeklyChart totals={weeklyTotals} />
      </Card>
    </div>
  )
}
