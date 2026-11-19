/**
 * Kitap formlarının (kitap ekle/düzenle, ilerleme gir) alanları. Yalnızca token sınıfları.
 * İkinci bir modül ihtiyaç duyarsa `src/ui`'a taşınmalı (CLAUDE.md protokolü).
 */
import {
  useId,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react'
import { cx } from '@/ui'

const CONTROL =
  'min-h-11 w-full rounded-md bg-fill px-3 py-2 text-body text-label placeholder:text-secondary-label disabled:opacity-60'

interface FieldShellProps {
  label: string
  hint?: ReactNode
  children: (ids: { inputId: string; hintId: string | undefined }) => ReactNode
}

function FieldShell({ label, hint, children }: FieldShellProps) {
  const inputId = useId()
  const hintId = useId()
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={inputId} className="text-subheadline font-semibold text-label">
        {label}
      </label>
      {children({ inputId, hintId: hint ? hintId : undefined })}
      {hint && (
        <p id={hintId} className="text-footnote text-secondary-label">
          {hint}
        </p>
      )}
    </div>
  )
}

export interface TextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'id'> {
  label: string
  hint?: ReactNode
}

/** Etiketli metin/sayı girişi (`type` ile). */
export function TextField({ label, hint, className, ...rest }: TextFieldProps) {
  return (
    <FieldShell label={label} hint={hint}>
      {({ inputId, hintId }) => (
        <input
          id={inputId}
          aria-describedby={hintId}
          className={cx(CONTROL, className)}
          {...rest}
        />
      )}
    </FieldShell>
  )
}

export interface TextAreaFieldProps extends Omit<
  TextareaHTMLAttributes<HTMLTextAreaElement>,
  'id'
> {
  label: string
  hint?: ReactNode
}

export function TextAreaField({ label, hint, className, rows = 3, ...rest }: TextAreaFieldProps) {
  return (
    <FieldShell label={label} hint={hint}>
      {({ inputId, hintId }) => (
        <textarea
          id={inputId}
          rows={rows}
          aria-describedby={hintId}
          className={cx(CONTROL, 'resize-y', className)}
          {...rest}
        />
      )}
    </FieldShell>
  )
}

export interface SelectFieldProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'id'> {
  label: string
  hint?: ReactNode
  children: ReactNode
}

/** Yerel `<select>` (iOS'ta sistem seçicisi açılır). Seçenekleri `children` ile ver. */
export function SelectField({ label, hint, className, children, ...rest }: SelectFieldProps) {
  return (
    <FieldShell label={label} hint={hint}>
      {({ inputId, hintId }) => (
        <select
          id={inputId}
          aria-describedby={hintId}
          className={cx(CONTROL, 'appearance-auto', className)}
          {...rest}
        >
          {children}
        </select>
      )}
    </FieldShell>
  )
}

/** Form hatası (ekran okuyucuya duyurulur). */
export function FormError({ children }: { children: ReactNode }) {
  return (
    <p role="alert" className="text-subheadline text-danger">
      {children}
    </p>
  )
}
