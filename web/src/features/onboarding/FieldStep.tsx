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
      subtitle="Derslerin ve konuların buna göre hazırlanır."
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
        <div className="flex flex-col border-t border-separator">
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
        'relative flex min-h-11 cursor-pointer items-start gap-4 border-b border-separator py-5 pl-4 transition-[background-color,transform] duration-200 ease-standard hover:bg-fill active:scale-97 has-focus-visible:outline-2 has-focus-visible:outline-accent-ink motion-reduce:active:scale-100',
        checked && 'bg-fill',
      )}
    >
      <span
        aria-hidden="true"
        className={cx(
          'absolute inset-y-0 left-0 w-1 transition-colors',
          checked ? 'bg-accent' : 'bg-transparent',
        )}
      />
      <input
        type="radio"
        name="yks-field"
        value={field}
        checked={checked}
        onChange={onSelect}
        aria-describedby={descriptionId}
        className="peer sr-only"
      />
      <span
        aria-hidden="true"
        className="w-10 shrink-0 pt-0.5 numeric text-footnote text-secondary-label"
      >
        {field}
      </span>
      <span>
        <span className="block text-headline">{FIELD_LABELS[field]}</span>
        <span id={descriptionId} className="mt-1 block text-subheadline text-secondary-label">
          {FIELD_DESCRIPTIONS[field]}
        </span>
      </span>
    </label>
  )
}
