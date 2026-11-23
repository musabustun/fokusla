/** Kitap formunun barkod alanı, "Kütüphanede ara" düğmesi ve sonuç satırları. */
import { Link } from 'react-router'
import { Button, FIELD_HINT_CLASS, ListRow, ListSection } from '@/ui'
import type { BarcodeLookup } from './useBarcodeLookup'
import { formatSectionRange } from './bookLabels'
import { TextField } from './FormField'
import { bookPath } from './paths'

export interface BarcodeSectionProps {
  value: string
  onChange: (value: string) => void
  onSearch: () => void
  isSearching: boolean
  lookup: BarcodeLookup
  /** Bulunan kitabın bölümlerini göster (yalnızca yeni kitapta). */
  showSections: boolean
}

function LookupResult({
  lookup,
  showSections,
}: Pick<BarcodeSectionProps, 'lookup' | 'showSections'>) {
  if (lookup.status === 'owned') {
    return (
      <p className={FIELD_HINT_CLASS} role="status">
        Bu kitap zaten kitaplığında:{' '}
        <Link
          to={bookPath(lookup.book.id)}
          className="inline-flex min-h-11 items-center font-medium text-accent-ink underline"
        >
          {lookup.book.title}
        </Link>
      </p>
    )
  }
  if (lookup.status === 'notFound') {
    return (
      <p className={FIELD_HINT_CLASS} role="status">
        Bu kitap kütüphanede yok. Bilgileri elle gir.
      </p>
    )
  }
  if (lookup.status !== 'found') return null
  const { resolved } = lookup
  return (
    <>
      <p className={FIELD_HINT_CLASS} role="status">
        Kütüphanede bulundu: {resolved.title}
      </p>
      {showSections && resolved.sections.length > 0 && (
        <ListSection header={`Bölümler (${resolved.sections.length})`}>
          {resolved.sections.map((section) => (
            <ListRow
              key={section.order}
              title={section.title}
              subtitle={
                formatSectionRange(resolved.unit, section.startUnit, section.endUnit) ?? undefined
              }
            />
          ))}
        </ListSection>
      )}
    </>
  )
}

export function BarcodeSection({
  value,
  onChange,
  onSearch,
  isSearching,
  lookup,
  showSections,
}: BarcodeSectionProps) {
  const error = lookup.status === 'invalid' ? lookup.message : null
  return (
    <div className="flex flex-col gap-2">
      <TextField
        label="Barkod"
        inputMode="numeric"
        autoComplete="off"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder="İsteğe bağlı"
        error={error}
      />
      <Button
        type="button"
        variant="tinted"
        fullWidth
        loading={isSearching}
        disabled={value.trim() === ''}
        onClick={onSearch}
      >
        Kütüphanede ara
      </Button>
      <LookupResult lookup={lookup} showSections={showSections} />
    </div>
  )
}
