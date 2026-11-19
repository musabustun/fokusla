import { cx } from '../cx'

export interface ToggleProps {
  checked: boolean
  onChange: (checked: boolean) => void
  /** Zorunlu: anahtarın erişilebilir adı (ör. "iCloud senkronu"). */
  'aria-label': string
  disabled?: boolean
  className?: string
}

/**
 * iOS açma/kapama anahtarı (`role="switch"`). Görsel boyut 51×31'dir; dokunma alanı ≥44px'dir.
 * SwiftUI: `Toggle(isOn:)`.
 */
export function Toggle({
  checked,
  onChange,
  'aria-label': ariaLabel,
  disabled = false,
  className,
}: ToggleProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={ariaLabel}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cx(
        'inline-flex min-h-11 min-w-11 items-center justify-center disabled:cursor-not-allowed disabled:opacity-40',
        className,
      )}
    >
      <span
        aria-hidden
        className={cx(
          'flex h-7.75 w-12.75 items-center rounded-full border border-separator p-0.5 transition-colors',
          checked ? 'bg-accent' : 'bg-fill',
        )}
      >
        <span
          className={cx(
            'size-6.5 rounded-full shadow-sm transition-transform motion-reduce:transition-none',
            checked ? 'translate-x-5 bg-accent-contrast' : 'translate-x-0 bg-control-thumb',
          )}
        />
      </span>
    </button>
  )
}
