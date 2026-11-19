import { Button, PalettePicker, useTheme } from '@/ui'
import { OnboardingStepLayout } from './OnboardingStepLayout'

interface ThemeStepProps {
  onNext: () => void
  onBack: () => void
}

/** Renk teması seçimi: seçim hemen tüm ekrana uygulanır ve kalıcıdır. */
export function ThemeStep({ onNext, onBack }: ThemeStepProps) {
  const { palette, setPalette, resolved } = useTheme()
  return (
    <OnboardingStepLayout
      step="theme"
      title="Temanı seç"
      subtitle="İstediğin zaman Ayarlar'dan değiştirebilirsin."
      actions={
        <>
          <Button size="large" fullWidth onClick={onNext}>
            Devam
          </Button>
          <Button variant="plain" fullWidth onClick={onBack}>
            Geri
          </Button>
        </>
      }
    >
      <PalettePicker legend="Renk teması" value={palette} onChange={setPalette} mode={resolved} />
    </OnboardingStepLayout>
  )
}
