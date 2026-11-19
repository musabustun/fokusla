import { Cloud, Info, Palette, Scale, UserRound } from 'lucide-react'
import {
  ListRow,
  ListSection,
  ScreenHeader,
  SegmentedControl,
  useTheme,
  type SegmentedOption,
  type ThemePreference,
} from '@/ui'

const APP_VERSION = '0.1.0'

const THEME_OPTIONS: readonly SegmentedOption<ThemePreference>[] = [
  { value: 'system', label: 'Sistem' },
  { value: 'light', label: 'Açık' },
  { value: 'dark', label: 'Koyu' },
]

const ICON_CLASS = 'size-5.5'

function AppearanceSection() {
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

// Hesap, senkronizasyon ve hakkında bölümleri şimdilik sabit yer tutuculardır.
export function SettingsScreen() {
  return (
    <>
      <ScreenHeader title="Ayarlar" />
      <AppearanceSection />
      <ListSection header="Hesap" footer="Giriş yapmadan da tüm özellikler cihazında çalışır.">
        <ListRow
          title="Apple ile Giriş"
          icon={<UserRound className={ICON_CLASS} />}
          value="Yakında"
        />
      </ListSection>
      <ListSection header="Senkronizasyon">
        <ListRow
          title="iCloud"
          subtitle="Verilerin cihazların arasında eşitlenir"
          icon={<Cloud className={ICON_CLASS} />}
          value="Yakında"
        />
      </ListSection>
      <ListSection header="Hakkında" footer="Fokus ücretsiz ve reklamsızdır.">
        <ListRow title="Sürüm" icon={<Info className={ICON_CLASS} />} value={APP_VERSION} />
        <ListRow title="Lisans" icon={<Scale className={ICON_CLASS} />} value="Açık kaynak · MIT" />
      </ListSection>
    </>
  )
}
