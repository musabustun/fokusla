import { FIELD_DESCRIPTIONS, FIELD_LABELS, FIELD_SHORT_LABELS } from '@/curriculum'
import { useServices } from '@/data'
import type { UserProfile, YksField } from '@/domain'
import { FIELD_ERROR_CLASS, RadioRow, Sheet, cx } from '@/ui'
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
      <fieldset disabled={pending} className="pt-2">
        <legend className="sr-only">YKS alanı</legend>
        <div className="border-t border-separator">
          {FIELDS.map((field) => (
            <RadioRow
              key={field}
              name="settings-yks-field"
              value={field}
              code={FIELD_SHORT_LABELS[field]}
              title={FIELD_LABELS[field]}
              description={FIELD_DESCRIPTIONS[field]}
              checked={profile.field === field}
              onChange={() => void handleSelect(field)}
            />
          ))}
        </div>
      </fieldset>
      {error ? (
        <p role="alert" className={cx('mt-3', FIELD_ERROR_CLASS)}>
          {error}
        </p>
      ) : null}
    </Sheet>
  )
}
