import { Link } from 'react-router'
import type { BookSummary } from '@/domain/calc/books'
import { ListRow, ProgressBar, cx } from '@/ui'
import {
  BOOK_KIND_LABELS,
  BOOK_STATUS_LABELS,
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

function rowMeta({ book, reachedUnit, weeklyPace }: BookSummary): string {
  return [
    BOOK_KIND_LABELS[book.kind],
    formatProgressCount(book.unit, reachedUnit, book.totalUnits),
    formatPace(book.unit, weeklyPace),
  ]
    .filter((part): part is string => part !== null)
    .join(' · ')
}

/** Kitap listesinin tek satırı: başlık, tür · ilerleme · hız, ince ilerleme çubuğu. */
export function BookListRow({ summary, isSelected }: BookListRowProps) {
  const { book, ratio, status } = summary
  return (
    <ListRow
      title={<span className="block truncate">{book.title}</span>}
      subtitle={
        <>
          <span className="block truncate">{rowMeta(summary)}</span>
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
