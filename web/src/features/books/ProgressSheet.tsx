/** "İlerleme gir" sayfası: kitapta nereye kadar gelindiğini (ve opsiyonel not) kaydeder. */
import { TriangleAlert } from 'lucide-react'
import { useEffect, useId, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { useServices } from '@/data'
import type { BookSummary } from '@/domain/calc/books'
import { Button, Sheet } from '@/ui'
import { addProgress, BookValidationError } from './bookActions'
import { BOOK_UNIT_NOUNS, formatNumber } from './bookLabels'
import { FormError, TextAreaField, TextField } from './FormField'
import { parseReachedUnit } from './progressInput'

export interface ProgressSheetProps {
  open: boolean
  onClose: () => void
  summary: BookSummary
}

const INVALID_NUMBER = 'Geçerli bir sayı gir.'
const SAVE_FAILED = 'Kaydedilemedi. Lütfen tekrar dene.'

function progressWarnings(summary: BookSummary, value: number | null): string[] {
  if (value === null) return []
  const total = summary.book.totalUnits
  const warnings: string[] = []
  if (value < summary.reachedUnit) {
    warnings.push('Önceki kayıttan geride; düzeltme olarak kaydedilir.')
  }
  if (total !== null && total > 0 && value >= total) {
    warnings.push('Kitap tamamlandı olarak işaretlenecek.')
  }
  return warnings
}

function Warning({ children }: { children: ReactNode }) {
  return (
    <p className="flex items-start gap-1.5 text-footnote text-warning">
      <TriangleAlert aria-hidden className="mt-0.5 size-4 shrink-0" />
      <span>{children}</span>
    </p>
  )
}

/**
 * Sayfa açıldığında kapsayıcıdaki ilk `<input>`'u odaklar ve seçer. Dialog, çocuk efektlerinden
 * sonra açıldığı için bir sonraki tura ertelenir.
 */
function useFocusAndSelect() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const input = ref.current?.querySelector('input')
      input?.focus()
      input?.select()
    }, 0)
    return () => window.clearTimeout(timer)
  }, [])
  return ref
}

interface ProgressFormProps {
  formId: string
  summary: BookSummary
  onSaved: () => void
  onSavingChange: (saving: boolean) => void
}

/** Sheet her açıldığında yeniden bağlanır; durum (girdi, hata) böylece sıfırlanır. */
function ProgressForm({ formId, summary, onSaved, onSavingChange }: ProgressFormProps) {
  const { repositories } = useServices()
  const { book } = summary
  const [reached, setReached] = useState(summary.reachedUnit > 0 ? String(summary.reachedUnit) : '')
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)
  const fieldRef = useFocusAndSelect()

  const parsed = parseReachedUnit(reached)
  const warnings = progressWarnings(summary, parsed)
  const total = book.totalUnits !== null && book.totalUnits > 0 ? book.totalUnits : null

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (parsed === null) {
      setError(INVALID_NUMBER)
      fieldRef.current?.querySelector('input')?.focus()
      return
    }
    setError(null)
    onSavingChange(true)
    try {
      await addProgress(repositories, { bookId: book.id, reachedUnit: parsed, note })
      onSaved()
    } catch (cause) {
      if (cause instanceof BookValidationError) {
        setError(cause.message)
      } else {
        console.error('İlerleme kaydedilemedi', cause)
        setError(SAVE_FAILED)
      }
    } finally {
      onSavingChange(false)
    }
  }

  return (
    <form id={formId} noValidate onSubmit={handleSubmit} className="flex flex-col gap-4 pt-2">
      <div ref={fieldRef} className="flex flex-col gap-2">
        <TextField
          label={`Ulaştığın ${BOOK_UNIT_NOUNS[book.unit]}`}
          hint={total !== null ? `Toplam: ${formatNumber(total)}` : undefined}
          type="number"
          inputMode="numeric"
          min={0}
          step={1}
          value={reached}
          onChange={(event) => setReached(event.target.value)}
          aria-invalid={error === INVALID_NUMBER || undefined}
        />
        {warnings.length > 0 && (
          <div aria-live="polite" className="flex flex-col gap-1">
            {warnings.map((warning) => (
              <Warning key={warning}>{warning}</Warning>
            ))}
          </div>
        )}
      </div>
      <TextAreaField
        label="Not"
        hint="İsteğe bağlı"
        value={note}
        onChange={(event) => setNote(event.target.value)}
      />
      {error && <FormError>{error}</FormError>}
    </form>
  )
}

export function ProgressSheet({ open, onClose, summary }: ProgressSheetProps) {
  const formId = useId()
  const [saving, setSaving] = useState(false)
  return (
    <Sheet
      open={open}
      onClose={onClose}
      title="İlerleme gir"
      description="Nereye kadar geldin?"
      footer={
        <Button type="submit" form={formId} size="large" fullWidth loading={saving}>
          Kaydet
        </Button>
      }
    >
      <ProgressForm
        formId={formId}
        summary={summary}
        onSaved={onClose}
        onSavingChange={setSaving}
      />
    </Sheet>
  )
}
