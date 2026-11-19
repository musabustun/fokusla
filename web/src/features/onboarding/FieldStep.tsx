import { FIELD_DESCRIPTIONS, FIELD_LABELS } from '@/curriculum'
import type { YksField } from '@/domain'
import { Button, cx } from '@/ui'
import { OnboardingStepLayout } from './OnboardingStepLayout'

interface FieldStepProps {
  value: YksField | null
  onChange: (field: YksField) => void
  onNext: () => void
  onBack: () => void
}

const FIELDS: readonly YksField[] = ['SAY', 'EA', 'SOZ', 'DIL']

export function FieldStep({ value, onChange, onNext, onBack }: FieldStepProps) {
  return (
    <OnboardingStepLayout
      step="field"
      title="Alanın hangisi?"
      subtitle="Derslerin ve konuların buna göre hazırlanır. Sonra Ayarlar'dan değiştirebilirsin."
      actions={
        <>
          <Button size="large" fullWidth disabled={value === null} onClick={onNext}>
            Devam
          </Button>
          <Button variant="plain" fullWidth onClick={onBack}>
            Geri
          </Button>
        </>
      }
    >
      <fieldset>
        <legend className="sr-only">YKS alanı</legend>
        <div className="flex flex-col gap-3">
          {FIELDS.map((field) => (
            <FieldOption
              key={field}
              field={field}
              checked={value === field}
              onSelect={() => onChange(field)}
            />
          ))}
        </div>
      </fieldset>
    </OnboardingStepLayout>
  )
}

interface FieldOptionProps {
  field: YksField
  checked: boolean
  onSelect: () => void
}

function FieldOption({ field, checked, onSelect }: FieldOptionProps) {
  const descriptionId = `field-${field}-description`
  return (
    <label
      className={cx(
        'flex min-h-11 cursor-pointer gap-3 rounded-lg border-2 bg-surface p-4 transition-colors has-focus-visible:outline-2 has-focus-visible:outline-accent',
        checked ? 'border-accent' : 'border-transparent',
      )}
    >
      <input
        type="radio"
        name="yks-field"
        value={field}
        checked={checked}
        onChange={onSelect}
        aria-describedby={descriptionId}
        className="mt-0.5 size-5 shrink-0 accent-accent focus-visible:outline-none"
      />
      <span>
        <span className="block text-headline">{FIELD_LABELS[field]}</span>
        <span id={descriptionId} className="mt-1 block text-subheadline text-secondary-label">
          {FIELD_DESCRIPTIONS[field]}
        </span>
      </span>
    </label>
  )
}
