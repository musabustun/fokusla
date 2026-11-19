import type { ReactNode } from 'react'
import { FIELD_ERROR_CLASS, FIELD_HINT_CLASS, FIELD_LABEL_CLASS } from '@/ui'
import { errorIdFor } from './formStyles'

export interface FormFieldProps {
  /** Girişin id'si; etiket buna bağlanır. Girişe `fieldA11y(id, error)` yay. */
  id: string
  label: string
  error?: string
  /** Etiketin altında kısa ipucu. */
  hint?: string
  children: ReactNode
}

/** Görünür etiket + giriş + alan hatası. */
export function FormField({ id, label, error, hint, children }: FormFieldProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className={FIELD_LABEL_CLASS}>
        {label}
      </label>
      {children}
      {hint && !error && <p className={FIELD_HINT_CLASS}>{hint}</p>}
      {error && (
        <p id={errorIdFor(id)} className={FIELD_ERROR_CLASS}>
          {error}
        </p>
      )}
    </div>
  )
}
