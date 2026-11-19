/**
 * Kitap detayı (`/kitaplar/:bookId`): ilerleme, hız/tahmin, geçmiş ve eylemler.
 * iPhone'da tek başına; iPad'de (≥1024px) liste ekranının sağ sütununda gösterilir.
 */
import { BookX, ChevronLeft, Plus } from 'lucide-react'
import { useId, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useServices } from '@/data'
import type { BookProgress, Subject, UUID } from '@/domain'
import type { BookSummary } from '@/domain/calc/books'
import { Button, buttonStyles, cx, EmptyState } from '@/ui'
import { BookDetailActions } from './BookDetailActions'
import { BookFormSheet } from './BookFormSheet'
import { BookProgressCard, BookStatsSection } from './BookStats'
import { deleteBook, deleteProgress, setBookArchived } from './bookActions'
import { BOOK_KIND_LABELS } from './bookLabels'
import { FormError } from './FormField'
import { ProgressHistory } from './ProgressHistory'
import { ProgressSheet } from './ProgressSheet'
import { useBookHistory, useBooksData } from './useBooks'
import { useWideLayout } from './useWideLayout'

const ACTION_FAILED = 'İşlem tamamlanamadı. Lütfen tekrar dene.'

function BookNotFound() {
  return (
    <EmptyState
      icon={<BookX />}
      title="Kitap bulunamadı"
      message="Bu kitap silinmiş ya da hiç eklenmemiş olabilir."
      action={
        <Link to={ROUTES.books} className={buttonStyles({ variant: 'tinted' })}>
          Kitaplara dön
        </Link>
      }
    />
  )
}

function metaLine(summary: BookSummary, subjectsById: ReadonlyMap<UUID, Subject>): string {
  const { book } = summary
  const subject = book.subjectId ? subjectsById.get(book.subjectId)?.name : undefined
  return [BOOK_KIND_LABELS[book.kind], book.publisher, subject]
    .filter((part): part is string => Boolean(part))
    .join(' · ')
}

interface BookHeaderProps {
  titleId: string
  title: string
  meta: string
  isWide: boolean
}

function BookHeader({ titleId, title, meta, isWide }: BookHeaderProps) {
  return (
    <header className="mb-6">
      {!isWide && (
        <Link
          to={ROUTES.books}
          className="mb-1 -ml-2 inline-flex min-h-11 items-center gap-0.5 rounded-full pr-3 text-body text-secondary-label transition-[background-color,transform] duration-200 ease-standard hover:bg-fill active:scale-97 motion-reduce:active:scale-100"
        >
          <ChevronLeft aria-hidden className="size-6" strokeWidth={2.5} />
          Kitaplar
        </Link>
      )}
      {isWide ? (
        <h2 id={titleId} className="text-title2 text-balance">
          {title}
        </h2>
      ) : (
        <h1 id={titleId} className="text-large-title text-balance">
          {title}
        </h1>
      )}
      {meta && <p className="mt-1 text-subheadline text-secondary-label">{meta}</p>}
    </header>
  )
}

/** Hata yakalayıp kullanıcıya gösteren eylem çalıştırıcı. */
function useActionRunner() {
  const [error, setError] = useState<string | null>(null)
  const run = async (action: () => Promise<unknown>): Promise<boolean> => {
    setError(null)
    try {
      await action()
      return true
    } catch (cause) {
      console.error('Kitap işlemi başarısız', cause)
      setError(ACTION_FAILED)
      return false
    }
  }
  return { error, run }
}

interface BookDetailProps {
  summary: BookSummary
  subjects: readonly Subject[]
  subjectsById: ReadonlyMap<UUID, Subject>
}

function BookDetail({ summary, subjects, subjectsById }: BookDetailProps) {
  const { repositories } = useServices()
  const navigate = useNavigate()
  const isWide = useWideLayout()
  const titleId = useId()
  const { book } = summary
  const history = useBookHistory(book.id)
  const [isProgressOpen, setProgressOpen] = useState(false)
  const [isEditOpen, setEditOpen] = useState(false)
  const { error, run } = useActionRunner()
  const now = new Date()
  const isArchived = book.archivedAt !== null

  const handleDeleteEntry = (entry: BookProgress) => {
    void run(() => deleteProgress(repositories, entry.id))
  }
  const handleToggleArchive = () => {
    void run(() => setBookArchived(repositories, book.id, !isArchived))
  }
  const handleDeleteBook = async () => {
    const isDeleted = await run(() => deleteBook(repositories, book.id))
    if (isDeleted) void navigate(ROUTES.books, { replace: true })
  }

  return (
    <section aria-labelledby={titleId} className={cx('flex flex-col', isWide && 'pt-2')}>
      <BookHeader
        titleId={titleId}
        title={book.title}
        meta={metaLine(summary, subjectsById)}
        isWide={isWide}
      />
      <BookProgressCard summary={summary} />
      <Button
        size="large"
        fullWidth
        icon={<Plus aria-hidden className="size-5" />}
        onClick={() => setProgressOpen(true)}
        className="mt-4 mb-8"
      >
        İlerleme gir
      </Button>
      {error && (
        <div className="mb-4">
          <FormError>{error}</FormError>
        </div>
      )}
      <BookStatsSection summary={summary} now={now} />
      <ProgressHistory entries={history} unit={book.unit} now={now} onDelete={handleDeleteEntry} />
      <BookDetailActions
        isArchived={isArchived}
        onEdit={() => setEditOpen(true)}
        onToggleArchive={handleToggleArchive}
        onDelete={handleDeleteBook}
      />
      <ProgressSheet
        open={isProgressOpen}
        onClose={() => setProgressOpen(false)}
        summary={summary}
      />
      <BookFormSheet
        open={isEditOpen}
        onClose={() => setEditOpen(false)}
        book={book}
        subjects={subjects}
      />
    </section>
  )
}

export function BookDetailScreen() {
  const { bookId } = useParams()
  const data = useBooksData()
  if (data === undefined) return null
  const summary = data.summaries.find((s) => s.book.id === bookId)
  if (!summary) return <BookNotFound />
  return (
    <BookDetail
      key={summary.book.id}
      summary={summary}
      subjects={data.subjects}
      subjectsById={data.subjectsById}
    />
  )
}
