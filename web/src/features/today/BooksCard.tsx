import { useMemo } from 'react'
import { ROUTES } from '@/app/routes'
import { useNow } from '@/data'
import type { BookUnit, ISODate } from '@/domain'
import { summarizeBooks, type BookSummary } from '@/domain/calc/books'
import { booksInProgress } from '@/domain/calc/today'
import { ProgressBar } from '@/ui'
import { CardEmpty, TodayCard } from './TodayCard'
import { formatInteger, formatPercent } from './format'
import { useTodayBooksData } from './useTodayData'

export interface BooksCardProps {
  today: ISODate
  className?: string
}

const TITLE = 'Kitaplar'
/** Son 7 günlük hız/özet için dakikalık "şimdi" yeterli. */
const NOW_REFRESH_MS = 60_000

/** Sayı sonrası birim adı: "34 / 120 test", "120. sayfa". */
const UNIT_NOUNS: Readonly<Record<BookUnit, string>> = {
  page: 'sayfa',
  test: 'test',
  section: 'bölüm',
}

/** "34 / 120 test"; toplam bilinmiyorsa "34. test"; hiç ilerleme yoksa "Başlanmadı". */
function progressText({ book, reachedUnit, ratio }: BookSummary): string {
  const noun = UNIT_NOUNS[book.unit]
  if (ratio !== null && book.totalUnits !== null) {
    return `${formatInteger(reachedUnit)} / ${formatInteger(book.totalUnits)} ${noun}`
  }
  if (reachedUnit <= 0) return 'Başlanmadı'
  return `${formatInteger(reachedUnit)}. ${noun}`
}

function BookRow({ summary }: { summary: BookSummary }) {
  const { book, ratio } = summary
  return (
    <li className="py-2.5 first:pt-0 last:pb-0">
      <div className="flex items-baseline justify-between gap-3">
        <p className="min-w-0 truncate text-callout">{book.title}</p>
        {ratio !== null && (
          <p className="shrink-0 text-subheadline text-secondary-label tabular-nums">
            {formatPercent(ratio)}
          </p>
        )}
      </div>
      <p className="truncate text-footnote text-secondary-label">{progressText(summary)}</p>
      {ratio !== null && (
        <ProgressBar
          value={ratio}
          label={`${book.title} ilerlemesi`}
          tone="accent"
          size="small"
          className="mt-1.5"
        />
      )}
    </li>
  )
}

/** Kitaplar: devam eden (yoksa başlanmamış) en fazla 3 kitap, ilerleme metni ve çubuğu. */
export function BooksCard({ className }: BooksCardProps) {
  const data = useTodayBooksData()
  const now = useNow(NOW_REFRESH_MS)
  const books = useMemo(
    () => (data ? booksInProgress(summarizeBooks(data.books, data.progress, now)) : undefined),
    [data, now],
  )

  if (books === undefined) {
    return (
      <TodayCard title={TITLE} className={className}>
        <div aria-busy="true" className="min-h-16" />
      </TodayCard>
    )
  }

  if (books.length === 0) {
    return (
      <TodayCard title={TITLE} className={className}>
        <CardEmpty message="Devam eden kitabın yok." actionLabel="Kitap ekle" to={ROUTES.books} />
      </TodayCard>
    )
  }

  return (
    <TodayCard title={TITLE} linkTo={ROUTES.books} linkLabel="Tüm kitaplar" className={className}>
      <ul className="divide-y divide-separator">
        {books.map((summary) => (
          <BookRow key={summary.book.id} summary={summary} />
        ))}
      </ul>
    </TodayCard>
  )
}
