import { cx } from '../cx'

export interface InputStyleOptions {
  /** `<textarea>` için: yükseklik içerikle büyür, üstten hizalı. */
  multiline?: boolean
}

/**
 * Metin/sayı/tarih girişi ve `<select>` için ortak görünüm: şeffaf zemin, 1px `separator-strong`
 * çizgi (≥3:1), ≥44px. Hata durumu `aria-invalid` ile kırmızı çizgi. SwiftUI: `TextField` +
 * `.textFieldStyle(.plain)` + `RoundedRectangle().stroke(Color("SeparatorStrong"))`.
 *
 * `<input className={inputStyles()} aria-invalid={Boolean(error) || undefined} />`
 */
export function inputStyles({ multiline = false }: InputStyleOptions = {}): string {
  return cx(
    'w-full min-w-0 rounded-md border border-separator-strong bg-transparent px-3 text-body text-label',
    'placeholder:text-secondary-label read-only:text-secondary-label disabled:opacity-50',
    'transition-colors duration-200 hover:border-label',
    'aria-invalid:border-danger',
    multiline ? 'min-h-24 py-2.5' : 'min-h-11 py-2',
  )
}

/** Form alanı etiketi (`<label>`). */
export const FIELD_LABEL_CLASS = 'text-subheadline font-medium text-label'

/** Alan altı yardım metni. */
export const FIELD_HINT_CLASS = 'text-footnote text-secondary-label'

/** Alan altı hata metni (`role="alert"` ile birlikte). */
export const FIELD_ERROR_CLASS = 'text-footnote text-danger'
