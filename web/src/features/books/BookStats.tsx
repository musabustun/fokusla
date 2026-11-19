/** Kitap detayının ilerleme kartı ve özet satırları (hız, son ilerleme, tahmini bitiş). */
import { Archive, CircleCheck } from 'lucide-react'
import type { BookSummary } from '@/domain/calc/books'
import { Card, ListRow, ListSection, ProgressBar } from '@/ui'
import {
  addDays,
  formatDay,
  formatNumber,
  formatPace,
  formatPercent,
  formatPosition,
  formatProgressCount,
} from './bookLabels'

function StatusBadge({ status }: { status: BookSummary['status'] }) {
  if (status === 'completed') {
    return (
      <span className="inline-flex items-center gap-1 text-subheadline font-semibold text-success">
        <CircleCheck aria-hidden className="size-4" />
        Tamamlandı
      </span>
    )
  }
  if (status === 'archived') {
    return (
      <span className="inline-flex items-center gap-1 text-subheadline font-semibold text-secondary-label">
        <Archive aria-hidden className="size-4" />
        Arşivlendi
      </span>
    )
  }
  return null
}

/** Büyük yüzde, ilerleme çubuğu, "34 / 120 test" ve güncel konum. */
export function BookProgressCard({ summary }: { summary: BookSummary }) {
  const { book, ratio, reachedUnit, status } = summary
  const count = formatProgressCount(book.unit, reachedUnit, book.totalUnits)
  const position = reachedUnit > 0 ? formatPosition(book.unit, reachedUnit) : 'Henüz başlanmadı'

  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-start justify-between gap-3">
        <p className="text-title1 tabular-nums">{ratio === null ? count : formatPercent(ratio)}</p>
        <StatusBadge status={status} />
      </div>
      {ratio !== null && (
        <ProgressBar
          value={ratio}
          label="Kitap ilerlemesi"
          tone={status === 'completed' ? 'success' : 'accent'}
        />
      )}
      <p className="flex flex-wrap justify-between gap-x-3 text-subheadline text-secondary-label">
        <span>{ratio === null ? 'Toplam bilinmiyor' : count}</span>
        <span>{position}</span>
      </p>
    </Card>
  )
}

interface Estimate {
  value: string
  subtitle?: string
}

function estimateText(summary: BookSummary, now: Date): Estimate {
  if (summary.status === 'completed') return { value: 'Tamamlandı' }
  if (summary.ratio === null) return { value: '—', subtitle: 'Toplam girilirse hesaplanır' }
  const days = summary.daysToFinish
  if (days === null) return { value: '—', subtitle: 'Hız belli olunca hesaplanır' }
  return { value: `${formatDay(addDays(now, days), now)} (~${formatNumber(days)} gün)` }
}

/** "Son ilerleme", "Hız (son 7 gün)", "Tahmini bitiş" satırları. */
export function BookStatsSection({ summary, now }: { summary: BookSummary; now: Date }) {
  const { book, lastProgressAt, weeklyPace } = summary
  const estimate = estimateText(summary, now)
  return (
    <ListSection header="Özet">
      <ListRow
        title="Son ilerleme"
        value={lastProgressAt ? formatDay(new Date(lastProgressAt), now) : 'Henüz yok'}
      />
      <ListRow
        title="Hız (son 7 gün)"
        value={formatPace(book.unit, weeklyPace) ?? 'Yeterli veri yok'}
      />
      <ListRow title="Tahmini bitiş" subtitle={estimate.subtitle} value={estimate.value} />
    </ListSection>
  )
}
