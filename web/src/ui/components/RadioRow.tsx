import { Check } from 'lucide-react'
import { useId, type ReactNode } from 'react'
import { cx } from '../cx'

export interface RadioRowProps {
  /** Radyo grubunun adı (aynı gruptaki satırlar aynı `name`'i paylaşır). */
  name: string
  value: string
  checked: boolean
  onChange: () => void
  /** Birincil metin; radyonun erişilebilir adı (yalnızca bu, açıklama değil). */
  title: ReactNode
  /** Altındaki açıklama (`aria-describedby`). */
  description?: ReactNode
  /** Soldaki küçük mono etiket (ör. "SAY"); dekoratif (`aria-hidden`). */
  code?: ReactNode
  disabled?: boolean
}

/**
 * Seçenek satırı: çizgili liste satırı + gerçek `<input type="radio">` (satırın tamamını kaplar,
 * görünmez — tıklama/dokunma doğrudan radyoya gider). Seçili: solda kehribar işaret, `fill` zemin
 * ve sağda onay. Bir `<fieldset>` içinde, üstü `border-t border-separator` olan bir kapsayıcıda
 * kullanılır. SwiftUI: `Picker(...).pickerStyle(.inline)` veya `List` + `.listRowBackground`.
 */
export function RadioRow({
  name,
  value,
  checked,
  onChange,
  title,
  description,
  code,
  disabled = false,
}: RadioRowProps) {
  const titleId = useId()
  const descriptionId = useId()
  return (
    <label
      className={cx(
        'relative flex min-h-13 cursor-pointer items-start gap-4 border-b border-separator py-4 pr-3 pl-4',
        'transition-[background-color,transform] duration-200 ease-standard hover:bg-fill active:scale-99 motion-reduce:active:scale-100',
        'has-focus-visible:outline-2 has-focus-visible:outline-accent-ink has-disabled:cursor-not-allowed has-disabled:opacity-50',
        checked && 'bg-fill',
      )}
    >
      <span
        aria-hidden
        className={cx(
          'absolute inset-y-0 left-0 w-1 transition-colors duration-200',
          checked ? 'bg-accent' : 'bg-transparent',
        )}
      />
      <input
        type="radio"
        name={name}
        value={value}
        checked={checked}
        onChange={onChange}
        disabled={disabled}
        aria-labelledby={titleId}
        aria-describedby={description ? descriptionId : undefined}
        className="absolute inset-0 size-full cursor-pointer appearance-none opacity-0 disabled:cursor-not-allowed"
      />
      {code && (
        <span
          aria-hidden
          className="w-10 shrink-0 pt-0.5 numeric text-footnote text-secondary-label"
        >
          {code}
        </span>
      )}
      <span className="min-w-0 flex-1">
        <span id={titleId} className="block text-headline">
          {title}
        </span>
        {description && (
          <span id={descriptionId} className="mt-1 block text-subheadline text-secondary-label">
            {description}
          </span>
        )}
      </span>
      <Check
        aria-hidden
        strokeWidth={2.5}
        className={cx(
          'mt-0.5 size-5 shrink-0 text-accent-ink transition-opacity duration-200',
          checked ? 'opacity-100' : 'opacity-0',
        )}
      />
    </label>
  )
}
