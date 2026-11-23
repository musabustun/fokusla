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
import { cx, FIELD_HINT_CLASS, FIELD_LABEL_CLASS, FIELD_ERROR_CLASS, inputStyles } from '@/ui'

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
      <label htmlFor={inputId} className={FIELD_LABEL_CLASS}>
        {label}
      </label>
      {children({ inputId, hintId: hint ? hintId : undefined })}
      {hint && (
        <p id={hintId} className={FIELD_HINT_CLASS}>
          {hint}
        </p>
      )}
    </div>
  )
}

export interface TextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'id'> {
  label: string
  hint?: ReactNode
  /** Alan hatası; verilirse alan `aria-invalid` olur ve mesaj duyurulur. */
  error?: string | null
}

/** Etiketli metin/sayı girişi (`type` ile). */
export function TextField({ label, hint, error, className, ...rest }: TextFieldProps) {
  const errorId = useId()
  return (
    <FieldShell label={label} hint={hint}>
      {({ inputId, hintId }) => (
        <>
          <input
            id={inputId}
            aria-describedby={
              [hintId, error ? errorId : undefined].filter(Boolean).join(' ') || undefined
            }
            aria-invalid={error ? true : undefined}
            className={cx(inputStyles(), className)}
            {...rest}
          />
          {error && (
            <p id={errorId} role="alert" className={FIELD_ERROR_CLASS}>
              {error}
            </p>
          )}
        </>
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
          className={cx(inputStyles({ multiline: true }), 'resize-y', className)}
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
          className={cx(inputStyles(), 'appearance-auto', className)}
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
    <p role="alert" className={FIELD_ERROR_CLASS}>
      {children}
    </p>
  )
}
