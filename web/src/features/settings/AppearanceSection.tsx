import { Palette } from 'lucide-react'
import {
  ListRow,
  ListSection,
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
  const { preference, setPreference } = useTheme()
  return (
    <ListSection header="Görünüm" footer="Sistem, cihazının açık/koyu ayarını izler.">
      <ListRow
        title="Tema"
        icon={<Palette className={ICON_CLASS} />}
        accessory={
          <SegmentedControl
            aria-label="Tema"
            options={THEME_OPTIONS}
            value={preference}
            onChange={setPreference}
          />
        }
      />
    </ListSection>
  )
}
