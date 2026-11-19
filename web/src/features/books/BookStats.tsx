/** Kitap detayının ilerleme kartı ve özet satırları (hız, son ilerleme, tahmini bitiş). */
import { Archive, CircleCheck } from 'lucide-react'
import type { BookSummary } from '@/domain/calc/books'
import { useId } from 'react'
import { Card, cx, Metric, ProgressBar } from '@/ui'
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

/** Büyük yüzde (ana öğe), ilerleme çubuğu, "34 / 120 test" ve güncel konum. */
export function BookProgressCard({ summary }: { summary: BookSummary }) {
  const { book, ratio, reachedUnit, status } = summary
  const count = formatProgressCount(book.unit, reachedUnit, book.totalUnits)
  const position = reachedUnit > 0 ? formatPosition(book.unit, reachedUnit) : 'Henüz başlanmadı'

  return (
    <Card className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-3">
        <p className={cx('numeric', ratio === null ? 'text-numeral-lg' : 'text-numeral-xl')}>
          {ratio === null ? count : formatPercent(ratio)}
        </p>
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
        <span className="numeric">{ratio === null ? 'Toplam bilinmiyor' : count}</span>
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

/** "Son ilerleme", "Hız (son 7 gün)", "Tahmini bitiş": Metric'ler, aralarında 1px çizgi. */
export function BookStatsSection({ summary, now }: { summary: BookSummary; now: Date }) {
  const { book, lastProgressAt, weeklyPace } = summary
  const estimate = estimateText(summary, now)
  const headingId = useId()
  return (
    <section aria-labelledby={headingId} className="mb-10">
      <h2 id={headingId} className="mb-2 eyebrow">
        Özet
      </h2>
      <div className="flex flex-col divide-y divide-separator border-y border-separator px-2">
        <Metric
          size="md"
          className="py-4"
          label="Son ilerleme"
          value={lastProgressAt ? formatDay(new Date(lastProgressAt), now) : 'Henüz yok'}
        />
        <Metric
          size="md"
          className="py-4"
          label="Hız (son 7 gün)"
          value={formatPace(book.unit, weeklyPace) ?? 'Yeterli veri yok'}
        />
        <Metric
          size="md"
          className="py-4"
          label="Tahmini bitiş"
          value={estimate.value}
          caption={estimate.subtitle}
        />
      </div>
    </section>
  )
}
