import { cx } from '../cx'

export interface SwitchProps {
  checked: boolean
  onChange: (checked: boolean) => void
  /** Görünür bir etiket yoksa erişilebilir ad (ör. "Bildirimler"). */
  'aria-label'?: string
  /** Görünür etiketin id'si (ör. ListRow başlığına verilen id) — tercih edilen yol. */
  'aria-labelledby'?: string
  'aria-describedby'?: string
  disabled?: boolean
  id?: string
  className?: string
}

// 44×44 dokunma alanı; görsel ray iOS'taki gibi 51×31, topuz 27px ve 2px iç boşluk.
const HIT_AREA =
  'inline-flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-full select-none disabled:cursor-not-allowed disabled:opacity-40'
const TRACK =
  'relative flex h-7.75 w-12.75 items-center rounded-full p-0.5 transition-colors duration-200 motion-reduce:transition-none'
const THUMB =
  'size-6.75 rounded-full shadow-sm transition-transform duration-200 ease-out motion-reduce:transition-none'

/**
 * iOS anahtarı (SwiftUI `Toggle(isOn:).toggleStyle(.switch)`). Durum yalnızca renkle değil topuzun
 * konumuyla da anlatılır; topuz her iki durumda da rayına karşı ≥ 3:1 kontrastlıdır.
 */
export function Switch({
  checked,
  onChange,
  'aria-label': ariaLabel,
  'aria-labelledby': ariaLabelledBy,
  'aria-describedby': ariaDescribedBy,
  disabled = false,
  id,
  className,
}: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      id={id}
      aria-checked={checked}
      aria-label={ariaLabel}
      aria-labelledby={ariaLabelledBy}
      aria-describedby={ariaDescribedBy}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cx(HIT_AREA, className)}
    >
      <span
        aria-hidden="true"
        data-switch-track
        className={cx(TRACK, checked ? 'bg-accent' : 'bg-fill')}
      >
        <span
          data-switch-thumb
          className={cx(
            THUMB,
            checked ? 'translate-x-5 bg-accent-contrast' : 'translate-x-0 bg-switch-thumb-off',
          )}
        />
      </span>
    </button>
  )
}
