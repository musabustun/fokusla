/** Kitap detayında kitabın bölümleri ve (varsa) barkodu. */
import type { Book } from '@/domain'
import { ListRow, ListSection } from '@/ui'
import { formatSectionRange } from './bookLabels'
import { useBookSections } from './useBooks'

export function BookSections({ book }: { book: Book }) {
  const data = useBookSections(book.id)
  const sections = data?.sections ?? []
  return (
    <>
      {sections.length > 0 && data && (
        <ListSection header="Bölümler">
          {sections.map((section) => {
            const topic = section.topicId ? data.topicNames.get(section.topicId) : undefined
            const subtitle = [
              formatSectionRange(book.unit, section.startUnit, section.endUnit),
              topic,
            ]
              .filter((part): part is string => Boolean(part))
              .join(' · ')
            return (
              <ListRow key={section.id} title={section.title} subtitle={subtitle || undefined} />
            )
          })}
        </ListSection>
      )}
      {book.barcode && (
        <ListSection>
          <ListRow title="Barkod" value={<span className="numeric">{book.barcode}</span>} />
        </ListSection>
      )}
    </>
  )
}
