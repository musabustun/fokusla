import { Flame, Trash2 } from 'lucide-react'
import { useId, useState, type FormEvent } from 'react'
import { Button, ProgressRing } from '@/ui'
import type { CompletionRate } from '@/domain/calc/tasks'
import { formatNumber, streakText } from './format'
import { INPUT_CLASS } from './styles'
import { QUANTITY_MAX, parseQuantity } from './taskModel'

const QUANTITY_ERROR = `1 ile ${formatNumber(QUANTITY_MAX)} arasında bir tam sayı gir`

export interface RoutineStatsProps {
  rate: CompletionRate
  streak: number
}

/** Rutin istatistiği: son 7 gün halkası + seri. */
export function RoutineStats({ rate, streak }: RoutineStatsProps) {
  return (
    <div className="flex items-center gap-4 rounded-md bg-background p-3">
      <ProgressRing
        value={rate.rate ?? 0}
        size={84}
        strokeWidth={8}
        tone={rate.rate === 1 ? 'success' : 'accent'}
        label="Son 7 gün tamamlama oranı"
      >
        <span className="flex flex-col items-center leading-none">
          <span className="text-headline">
            {formatNumber(rate.completed)}/{formatNumber(rate.scheduled)}
          </span>
          <span className="mt-1 text-caption text-secondary-label">gün</span>
        </span>
      </ProgressRing>
      <div className="min-w-0">
        <p className="text-footnote text-secondary-label">Son 7 gün</p>
        <p className="mt-1 flex items-center gap-1.5 text-headline">
          <Flame aria-hidden className="size-5 shrink-0 text-warning" />
          {streak > 0 ? streakText(streak) : 'Henüz seri yok'}
        </p>
      </div>
    </div>
  )
}

export interface QuantityFormProps {
  initial: number | null | undefined
  unit: string | null | undefined
  pending: boolean
  onSave: (quantity: number | null) => void
}

/** "Gerçekleşen miktar" girişi; kaydetmek görevi de tamamlar. */
export function QuantityForm({ initial, unit, pending, onSave }: QuantityFormProps) {
  const id = useId()
  const [value, setValue] = useState(initial == null ? '' : String(initial))
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const quantity = parseQuantity(value)
    if (quantity === undefined) {
      setError(QUANTITY_ERROR)
      return
    }
    setError(null)
    onSave(quantity)
  }

  return (
    <form noValidate onSubmit={handleSubmit} className="flex flex-col gap-1.5">
      <label htmlFor={`${id}-input`} className="text-subheadline font-semibold">
        Gerçekleşen miktar
      </label>
      <div className="flex items-center gap-2">
        <div className="relative min-w-0 flex-1">
          <input
            id={`${id}-input`}
            type="number"
            inputMode="numeric"
            min={1}
            step={1}
            value={value}
            onChange={(event) => setValue(event.target.value)}
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? `${id}-error` : undefined}
            className={unit ? `${INPUT_CLASS} pr-16` : INPUT_CLASS}
          />
          {unit && (
            <span
              aria-hidden
              className="pointer-events-none absolute top-1/2 right-3 max-w-14 -translate-y-1/2 truncate text-subheadline text-secondary-label"
            >
              {unit}
            </span>
          )}
        </div>
        <Button type="submit" variant="tinted" size="small" loading={pending}>
          Miktarı kaydet
        </Button>
      </div>
      {error && (
        <p id={`${id}-error`} className="text-footnote text-danger">
          {error}
        </p>
      )}
    </form>
  )
}

export interface DeleteControlProps {
  pending: boolean
  onConfirm: () => void
}

/** "Sil" → satır içi onay ("Bu görev silinsin mi?" Vazgeç / Sil). */
export function DeleteControl({ pending, onConfirm }: DeleteControlProps) {
  const [confirming, setConfirming] = useState(false)
  const promptId = useId()

  if (!confirming) {
    return (
      <Button
        variant="destructive"
        icon={<Trash2 aria-hidden className="size-4" />}
        onClick={() => setConfirming(true)}
      >
        Sil
      </Button>
    )
  }
  return (
    <div
      role="group"
      aria-labelledby={promptId}
      className="flex w-full flex-col gap-2 rounded-md bg-background p-3"
    >
      <p id={promptId} className="text-subheadline font-semibold text-danger">
        Bu görev silinsin mi?
      </p>
      <p className="text-footnote text-secondary-label">
        Görev ve tamamlama geçmişi listelerden kaldırılır.
      </p>
      <div className="flex justify-end gap-2">
        <Button variant="plain" size="small" autoFocus onClick={() => setConfirming(false)}>
          Vazgeç
        </Button>
        <Button variant="destructive" size="small" loading={pending} onClick={onConfirm}>
          Sil
        </Button>
      </div>
    </div>
  )
}
