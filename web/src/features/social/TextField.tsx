import { useId, type InputHTMLAttributes, type ReactNode } from 'react'
import { cx, FIELD_ERROR_CLASS, FIELD_HINT_CLASS, FIELD_LABEL_CLASS, inputStyles } from '@/ui'

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
  const sharedProps = {
    id: inputId,
    value,
    onChange: (event: React.ChangeEvent<HTMLInputElement>) => onValueChange(event.target.value),
    'aria-invalid': error ? true : undefined,
    'aria-describedby': message ? messageId : undefined,
    ...inputProps,
  }
  return (
    <div className={cx('flex flex-col gap-1.5', className)}>
      <label htmlFor={inputId} className={FIELD_LABEL_CLASS}>
        {label}
      </label>
      {prefix ? (
        <div
          className={cx(
            inputStyles(),
            'flex items-center gap-0.5 focus-within:outline-2 focus-within:outline-accent-ink',
            error && 'border-danger',
          )}
        >
          <span aria-hidden className="text-body text-secondary-label">
            {prefix}
          </span>
          <input
            {...sharedProps}
            className="min-h-11 w-full min-w-0 bg-transparent text-body text-label placeholder:text-secondary-label focus:outline-none"
          />
        </div>
      ) : (
        <input {...sharedProps} className={inputStyles()} />
      )}
      {message && (
        <p
          id={messageId}
          role={error ? 'alert' : undefined}
          className={error ? FIELD_ERROR_CLASS : FIELD_HINT_CLASS}
        >
          {message}
        </p>
      )}
    </div>
  )
}
