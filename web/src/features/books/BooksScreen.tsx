/**
 * Kitaplar: derse göre gruplu liste (devam eden / biten).
 * iPhone (<1024px): liste → detay (detay açıkken yalnızca `<Outlet>`).
 * iPad (≥1024px): liste ve detay yan yana.
 */
import { BookOpen, Plus } from 'lucide-react'
import { useState } from 'react'
import { Outlet, useNavigate, useParams } from 'react-router'
import type { Book, Subject, UUID } from '@/domain'
import { groupBySubject, splitByFinished, type BookSummary } from '@/domain/calc/books'
import { Button, EmptyState, ListSection, ScreenHeader, SegmentedControl } from '@/ui'
import { BookFormSheet } from './BookFormSheet'
import { BookListRow } from './BookListRow'
import { bookPath } from './paths'
import { useBooksData } from './useBooks'
import { useWideLayout } from './useWideLayout'

type BookTab = 'active' | 'finished'

const TAB_OPTIONS = [
  { value: 'active', label: 'Devam eden' },
  { value: 'finished', label: 'Biten' },
] as const satisfies readonly { value: BookTab; label: string }[]

const EMPTY_TAB_TEXT: Record<BookTab, string> = {
  active: 'Devam eden kitap yok.',
  finished: 'Biten kitap yok.',
}

const NO_SUBJECT_HEADER = 'Ders seçilmedi'

interface BookGroupsProps {
  summaries: readonly BookSummary[]
  subjectsById: ReadonlyMap<UUID, Subject>
  selectedId: UUID | undefined
}

function BookGroups({ summaries, subjectsById, selectedId }: BookGroupsProps) {
  return groupBySubject(summaries).map((group) => (
    <ListSection
      key={group.subjectId ?? 'none'}
      header={
        group.subjectId === null
          ? NO_SUBJECT_HEADER
          : (subjectsById.get(group.subjectId)?.name ?? NO_SUBJECT_HEADER)
      }
    >
      {group.books.map((summary) => (
        <BookListRow
          key={summary.book.id}
          summary={summary}
          isSelected={summary.book.id === selectedId}
        />
      ))}
    </ListSection>
  ))
}

interface BookListBodyProps {
  summaries: readonly BookSummary[]
  subjectsById: ReadonlyMap<UUID, Subject>
  selectedId: UUID | undefined
  tab: BookTab
  onTabChange: (tab: BookTab) => void
  onAdd: () => void
}

function BookListBody({
  summaries,
  subjectsById,
  selectedId,
  tab,
  onTabChange,
  onAdd,
}: BookListBodyProps) {
  if (summaries.length === 0) {
    return (
      <EmptyState
        icon={<BookOpen />}
        title="Kitaplığın boş"
        message="Kullandığın kitapları ekle ve her kitapta nereye kadar geldiğini takip et."
        action={<Button onClick={onAdd}>İlk kitabını ekle</Button>}
      />
    )
  }

  const split = splitByFinished(summaries)
  const visible = tab === 'active' ? split.active : split.finished

  return (
    <>
      <SegmentedControl
        aria-label="Kitap durumu"
        options={TAB_OPTIONS}
        value={tab}
        onChange={onTabChange}
        fullWidth
        className="mb-6"
      />
      {visible.length === 0 ? (
        <p className="px-4 py-8 text-center text-subheadline text-secondary-label">
          {EMPTY_TAB_TEXT[tab]}
        </p>
      ) : (
        <BookGroups summaries={visible} subjectsById={subjectsById} selectedId={selectedId} />
      )}
    </>
  )
}

function DetailPlaceholder() {
  return (
    <EmptyState
      icon={<BookOpen />}
      title="Bir kitap seç"
      message="İlerlemesini görmek ve güncellemek için listeden bir kitap seç."
      className="rounded-lg bg-surface"
    />
  )
}

export function BooksScreen() {
  const data = useBooksData()
  const { bookId } = useParams()
  const isWide = useWideLayout()
  const navigate = useNavigate()
  const [isFormOpen, setFormOpen] = useState(false)
  // Ekranda tutulur: iPhone'da detaydan dönünce seçili sekme korunur.
  const [tab, setTab] = useState<BookTab>('active')

  // iPhone: detay tam ekran; kendi geri bağlantısı ve başlığı vardır.
  if (!isWide && bookId) return <Outlet />

  const openForm = () => setFormOpen(true)
  const handleSaved = (book: Book) => {
    void navigate(bookPath(book.id))
  }

  const list = (
    <>
      <ScreenHeader
        title="Kitaplar"
        subtitle="Soru bankaları ve kaynaklar"
        actions={
          <Button variant="plain" icon={<Plus aria-hidden className="size-5" />} onClick={openForm}>
            <span className="lg:sr-only">Kitap ekle</span>
          </Button>
        }
      />
      {data && (
        <BookListBody
          summaries={data.summaries}
          subjectsById={data.subjectsById}
          selectedId={bookId}
          tab={tab}
          onTabChange={setTab}
          onAdd={openForm}
        />
      )}
    </>
  )

  const sheet = (
    <BookFormSheet
      open={isFormOpen}
      onClose={() => setFormOpen(false)}
      subjects={data?.subjects ?? []}
      onSaved={handleSaved}
    />
  )

  if (!isWide) {
    return (
      <>
        {list}
        {sheet}
      </>
    )
  }

  return (
    <>
      <div className="flex items-start gap-6">
        <div className="w-68 shrink-0">{list}</div>
        <div className="min-w-0 flex-1">{bookId ? <Outlet /> : <DetailPlaceholder />}</div>
      </div>
      {sheet}
    </>
  )
}
