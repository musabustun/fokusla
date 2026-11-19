import type { ReactNode } from 'react'
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
      <label htmlFor={id} className="text-subheadline text-secondary-label">
        {label}
      </label>
      {children}
      {hint && !error && <p className="text-footnote text-secondary-label">{hint}</p>}
      {error && (
        <p id={errorIdFor(id)} className="text-footnote text-danger">
          {error}
        </p>
      )}
    </div>
  )
}
