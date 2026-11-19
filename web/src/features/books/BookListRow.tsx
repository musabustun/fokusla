import { Link } from 'react-router'
import type { BookSummary } from '@/domain/calc/books'
import { ListRow, ProgressBar, cx } from '@/ui'
import {
  addDays,
  BOOK_KIND_LABELS,
  BOOK_STATUS_LABELS,
  formatDay,
  formatPace,
  formatPercent,
  formatProgressCount,
} from './bookLabels'
import { bookPath } from './paths'

export interface BookListRowProps {
  summary: BookSummary
  /** iPad'de detayı açık olan kitap (vurgulanır, `aria-current="page"`). */
  isSelected: boolean
}

/** Sağdaki değer: biten kitapta durum, toplam biliniyorsa yüzde; yoksa hiçbir şey. */
function rowValue({ status, ratio }: BookSummary): string | undefined {
  if (status === 'completed' || status === 'archived') return BOOK_STATUS_LABELS[status]
  return ratio === null ? undefined : formatPercent(ratio)
}

/** "34 / 120 test · haftada ~12 test" (hız yoksa yalnızca ilerleme). */
function rowProgress({ book, reachedUnit, weeklyPace }: BookSummary): string {
  return [
    formatProgressCount(book.unit, reachedUnit, book.totalUnits),
    formatPace(book.unit, weeklyPace),
  ]
    .filter((part): part is string => part !== null)
    .join(' · ')
}

/** "Son: 18 Kasım · Bitiş ~9 Ocak 2027"; ilerleme yoksa tür adı + "henüz ilerleme yok". */
function rowTimeline(summary: BookSummary, now: Date): string {
  const { book, lastProgressAt, daysToFinish, status } = summary
  if (lastProgressAt === null) return `${BOOK_KIND_LABELS[book.kind]} · henüz ilerleme yok`
  const parts = [`Son: ${formatDay(new Date(lastProgressAt), now)}`]
  if (status === 'inProgress' && daysToFinish !== null && daysToFinish > 0) {
    parts.push(`Bitiş ~${formatDay(addDays(now, daysToFinish), now)}`)
  }
  return parts.join(' · ')
}

/** Kitap listesinin tek satırı: başlık, ilerleme · hız, son ilerleme · tahmini bitiş, çubuk. */
export function BookListRow({ summary, isSelected }: BookListRowProps) {
  const { book, ratio, status } = summary
  const now = new Date()
  return (
    <ListRow
      title={<span className="block truncate">{book.title}</span>}
      subtitle={
        <>
          <span className="block truncate">{rowProgress(summary)}</span>
          <span className="block truncate text-footnote">{rowTimeline(summary, now)}</span>
          {ratio !== null && (
            <ProgressBar
              value={ratio}
              size="small"
              tone={status === 'completed' ? 'success' : 'accent'}
              className="mt-1.5"
            />
          )}
        </>
      }
      value={rowValue(summary)}
      render={(props) => (
        <Link
          to={bookPath(book.id)}
          {...props}
          className={cx(props.className, isSelected && 'bg-fill')}
          aria-current={isSelected ? 'page' : undefined}
        />
      )}
    />
  )
}
