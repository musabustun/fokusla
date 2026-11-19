import { Check } from 'lucide-react'
import { useId } from 'react'
import { cx } from '../cx'
import { PALETTE_LABELS, PALETTE_NAMES, type PaletteName, type ThemeName } from '../tokens'
import { PalettePreview } from './PalettePreview'

export interface PalettePickerProps {
  value: PaletteName
  onChange: (palette: PaletteName) => void
  /** Önizlemelerin modu: uygulanan mod (`useTheme().resolved`). */
  mode: ThemeName
  /** Grubun erişilebilir adı. Varsayılan "Renk teması". */
  legend?: string
  className?: string
}

/**
 * Renk teması (palet) seçici: her palet adı ve canlı önizlemesiyle bir kart; gerçek
 * `<input type="radio">` (ok tuşlarıyla gezinilir). Seçim anında uygulanmak üzere `onChange`
 * çağrılır. iPhone'da 2, iPad'de 3 sütun. SwiftUI: `LazyVGrid` + `Picker` semantiği.
 */
export function PalettePicker({
  value,
  onChange,
  mode,
  legend = 'Renk teması',
  className,
}: PalettePickerProps) {
  const name = useId()
  return (
    <fieldset className={className}>
      <legend className="sr-only">{legend}</legend>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
        {PALETTE_NAMES.map((palette) => (
          <PaletteOption
            key={palette}
            name={name}
            palette={palette}
            mode={mode}
            checked={value === palette}
            onChange={() => onChange(palette)}
          />
        ))}
      </div>
    </fieldset>
  )
}

interface PaletteOptionProps {
  name: string
  palette: PaletteName
  mode: ThemeName
  checked: boolean
  onChange: () => void
}

function PaletteOption({ name, palette, mode, checked, onChange }: PaletteOptionProps) {
  const labelId = useId()
  return (
    <label
      className={cx(
        'relative flex min-h-11 cursor-pointer flex-col gap-2 rounded-lg border p-2 pb-2.5',
        'transition-[background-color,border-color,transform] duration-200 ease-standard hover:bg-fill active:scale-98 motion-reduce:active:scale-100',
        'has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-accent-ink',
        checked ? 'border-accent-ink bg-fill' : 'border-separator',
      )}
    >
      <input
        type="radio"
        name={name}
        value={palette}
        checked={checked}
        onChange={onChange}
        aria-labelledby={labelId}
        className="absolute inset-0 size-full cursor-pointer appearance-none opacity-0"
      />
      <PalettePreview palette={palette} mode={mode} />
      <span className="flex items-center justify-between gap-2 px-1">
        <span id={labelId} className="text-subheadline font-semibold">
          {PALETTE_LABELS[palette]}
        </span>
        <Check
          aria-hidden
          strokeWidth={2.5}
          className={cx(
            'size-4 shrink-0 text-accent-ink transition-opacity duration-200',
            checked ? 'opacity-100' : 'opacity-0',
          )}
        />
      </span>
    </label>
  )
}
