import type { DailyFocusTotal } from '@/domain/calc/focus'
import { Card, Metric } from '@/ui'
import { formatDurationText } from './formatDuration'
import { WeeklyChart } from './WeeklyChart'

export interface FocusStatsProps {
  averageFocusMs: number
  averageBreakMs: number
  weeklyTotals: readonly DailyFocusTotal[]
}

/** "1 sa 5 dk" → büyük rakamlar + küçük, ikincil birimler (boşluklu; metin olarak "1 sa 5 dk"). */
function DurationValue({ ms }: { ms: number }) {
  const tokens = formatDurationText(ms).split(' ')
  return (
    <>
      {tokens.map((token, index) =>
        index % 2 === 0 ? (
          <span key={index}>{token}</span>
        ) : (
          <span
            key={index}
            className="font-sans text-subheadline tracking-normal text-secondary-label"
          >
            {` ${token} `}
          </span>
        ),
      )}
    </>
  )
}

function StatRegion({
  title,
  valueMs,
  size,
  className,
}: {
  title: string
  valueMs: number
  size: 'xl' | 'lg'
  className?: string
}) {
  // `region` adı aria-label'dan gelir; görünür etiket Metric'te. Metin "25 dk" olarak okunur.
  return (
    <section aria-label={title} className={className}>
      <Metric label={title} value={<DurationValue ms={valueMs} />} size={size} />
    </section>
  )
}

/** Odak istatistikleri (büyük mono rakamlar, 1px çizgiler) ve son 7 günün grafiği. */
export function FocusStats({ averageFocusMs, averageBreakMs, weeklyTotals }: FocusStatsProps) {
  const weekTotalMs = weeklyTotals.reduce((sum, total) => sum + total.focusMs, 0)
  return (
    <div className="flex flex-col gap-10">
      <div className="border-t border-separator pt-6">
        <div className="grid grid-cols-2">
          <StatRegion title="Ortalama kesintisiz odak" valueMs={averageFocusMs} size="lg" />
          <StatRegion
            title="Ortalama mola"
            valueMs={averageBreakMs}
            size="lg"
            className="border-l border-separator pl-6"
          />
        </div>
      </div>
      <Card
        title="Son 7 gün"
        trailing={
          <span className="numeric text-subheadline text-secondary-label">
            {formatDurationText(weekTotalMs)}
          </span>
        }
      >
        <WeeklyChart totals={weeklyTotals} />
      </Card>
    </div>
  )
}
