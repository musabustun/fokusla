import { FIELD_DESCRIPTIONS, FIELD_LABELS } from '@/curriculum'
import { useServices } from '@/data'
import type { UserProfile, YksField } from '@/domain'
import { Sheet, cx } from '@/ui'
import { changeField } from './actions'
import { useAsyncAction } from './useAsyncAction'

const FIELDS: readonly YksField[] = ['SAY', 'EA', 'SOZ', 'DIL']

interface FieldSheetProps {
  open: boolean
  onClose: () => void
  profile: UserProfile
}

/** Alan seçimi anında kaydedilir; verilerin hiçbiri silinmez. */
export function FieldSheet({ open, onClose, profile }: FieldSheetProps) {
  const { repositories } = useServices()
  const { pending, error, run } = useAsyncAction()

  const handleSelect = async (field: YksField) => {
    if (await run(() => changeField({ repositories }, profile, field))) onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title="YKS alanı"
      description="Alanını değiştirirsen AYT/YDT dersleri buna göre görünür. Mevcut verilerin silinmez."
    >
      <fieldset disabled={pending} className="flex flex-col gap-3 pt-2">
        <legend className="sr-only">YKS alanı</legend>
        {FIELDS.map((field) => {
          const checked = profile.field === field
          const descriptionId = `settings-field-${field}-description`
          return (
            <label
              key={field}
              className={cx(
                'flex min-h-11 cursor-pointer gap-3 rounded-lg border-2 bg-surface p-4 transition-colors has-focus-visible:outline-2 has-focus-visible:outline-accent-ink',
                checked ? 'border-accent-ink' : 'border-transparent',
              )}
            >
              <input
                type="radio"
                name="settings-yks-field"
                value={field}
                checked={checked}
                onChange={() => void handleSelect(field)}
                aria-describedby={descriptionId}
                className="mt-0.5 size-5 shrink-0 accent-accent focus-visible:outline-none"
              />
              <span>
                <span className="block text-headline">{FIELD_LABELS[field]}</span>
                <span
                  id={descriptionId}
                  className="mt-1 block text-subheadline text-secondary-label"
                >
                  {FIELD_DESCRIPTIONS[field]}
                </span>
              </span>
            </label>
          )
        })}
      </fieldset>
      {error ? (
        <p role="alert" className="mt-3 text-subheadline text-danger">
          {error}
        </p>
      ) : null}
    </Sheet>
  )
}
