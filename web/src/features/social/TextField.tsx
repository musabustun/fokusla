import { useId, type InputHTMLAttributes, type ReactNode } from 'react'
import { cx } from '@/ui'

// Sosyal modülüne özel metin alanı. Başka bir modül de ihtiyaç duyarsa @/ui'ye taşınmalı.
interface TextFieldProps extends Omit<
  InputHTMLAttributes<HTMLInputElement>,
  'onChange' | 'value' | 'prefix'
> {
  label: string
  value: string
  onValueChange: (value: string) => void
  /** Alanın solunda sabit önek (ör. "@"). */
  prefix?: string
  hint?: ReactNode
  error?: string | null
}

export function TextField({
  label,
  value,
  onValueChange,
  prefix,
  hint,
  error,
  className,
  ...inputProps
}: TextFieldProps) {
  const inputId = useId()
  const messageId = useId()
  const message = error ?? hint
  return (
    <div className={cx('flex flex-col gap-1.5', className)}>
      <label htmlFor={inputId} className="text-subheadline font-semibold text-label">
        {label}
      </label>
      <div
        className={cx(
          'flex min-h-11 items-center rounded-md bg-fill px-3 focus-within:outline-2 focus-within:outline-accent-ink',
          error && 'outline-2 outline-danger',
        )}
      >
        {prefix && (
          <span aria-hidden className="pr-0.5 text-body text-secondary-label">
            {prefix}
          </span>
        )}
        <input
          id={inputId}
          value={value}
          onChange={(event) => onValueChange(event.target.value)}
          aria-invalid={error ? true : undefined}
          aria-describedby={message ? messageId : undefined}
          className="min-h-11 w-full min-w-0 bg-transparent text-body text-label placeholder:text-secondary-label focus:outline-none"
          {...inputProps}
        />
      </div>
      {message && (
        <p
          id={messageId}
          role={error ? 'alert' : undefined}
          className={cx('text-footnote', error ? 'text-danger' : 'text-secondary-label')}
        >
          {message}
        </p>
      )}
    </div>
  )
}
