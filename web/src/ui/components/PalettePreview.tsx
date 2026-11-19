import { cx } from '../cx'
import type { PaletteName, ThemeName } from '../tokens'
import { ProgressRing } from './ProgressRing'

export interface PalettePreviewProps {
  palette: PaletteName
  /** Önizlemenin modu; genellikle uygulanan mod (`useTheme().resolved`). */
  mode: ThemeName
  className?: string
}

/**
 * Bir paletin küçük canlı önizlemesi: o paletin zemini, ilerleme halkası ve ana düğme hapı.
 * `data-palette`/`data-theme` öznitelikleri token'ları bu kutu için yeniden tanımlar
 * (tokens.css), yani içerik yalnızca token sınıfları kullanır — ham renk yok. Dekoratiftir.
 * SwiftUI: aynı görünüm `.environment(\.palette, palette)` + `.environment(\.colorScheme, mode)`.
 */
export function PalettePreview({ palette, mode, className }: PalettePreviewProps) {
  return (
    <div
      aria-hidden
      data-palette={palette}
      data-theme={mode}
      className={cx(
        'flex items-center justify-between gap-2 rounded-md border border-separator bg-background px-3 py-3 text-label',
        className,
      )}
    >
      <ProgressRing value={0.66} size={36} strokeWidth={4} />
      <span className="flex flex-col items-end gap-1.5">
        <span className="h-1 w-8 rounded-full bg-separator-strong" />
        <span className="h-4 w-12 rounded-full bg-accent" />
      </span>
    </div>
  )
}
