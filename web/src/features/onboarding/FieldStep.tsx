import { FIELD_DESCRIPTIONS, FIELD_LABELS, FIELD_SHORT_LABELS } from '@/curriculum'
import type { YksField } from '@/domain'
import { Button, RadioRow } from '@/ui'
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
            <RadioRow
              key={field}
              name="yks-field"
              value={field}
              code={FIELD_SHORT_LABELS[field]}
              title={FIELD_LABELS[field]}
              description={FIELD_DESCRIPTIONS[field]}
              checked={value === field}
              onChange={() => onChange(field)}
            />
          ))}
        </div>
      </fieldset>
    </OnboardingStepLayout>
  )
}
