import { Sun } from 'lucide-react'
import {
  ListRow,
  ListSection,
  PalettePicker,
  SegmentedControl,
  useTheme,
  type SegmentedOption,
  type ThemePreference,
} from '@/ui'
import { ICON_CLASS } from './constants'

const THEME_OPTIONS: readonly SegmentedOption<ThemePreference>[] = [
  { value: 'system', label: 'Sistem' },
  { value: 'light', label: 'Açık' },
  { value: 'dark', label: 'Koyu' },
]

export function AppearanceSection() {
  const { preference, setPreference, palette, setPalette, resolved } = useTheme()
  return (
    <ListSection
      header="Görünüm"
      footer="Renk teması ve mod birbirinden bağımsızdır. Sistem, cihazının açık/koyu ayarını izler."
    >
      <ListRow
        title="Mod"
        icon={<Sun className={ICON_CLASS} />}
        accessory={
          <SegmentedControl
            aria-label="Mod"
            options={THEME_OPTIONS}
            value={preference}
            onChange={setPreference}
          />
        }
      />
      <li className="relative px-2 py-4 before:absolute before:top-0 before:right-2 before:left-2 before:h-px before:bg-separator">
        <PalettePicker value={palette} onChange={setPalette} mode={resolved} legend="Renk teması" />
      </li>
    </ListSection>
  )
}
