import { Button } from '@/ui'
import { OnboardingStepLayout } from './OnboardingStepLayout'

interface WelcomeStepProps {
  onNext: () => void
}

interface Highlight {
  title: string
  text: string
}

const HIGHLIGHTS: readonly Highlight[] = [
  { title: 'Odaklan', text: 'Kronometreyle çalış, molalarını ve günlük toplamını gör.' },
  { title: 'Analiz et', text: 'Konu konu testlerini, doğru-yanlışlarını ve netlerini takip et.' },
  { title: 'Planla', text: 'Kitaplarında nerede kaldığını, rutinlerini ve ödevlerini tut.' },
]

export function WelcomeStep({ onNext }: WelcomeStepProps) {
  return (
    <OnboardingStepLayout
      step="welcome"
      brand
      title="Fokus'a hoş geldin"
      subtitle="YKS hazırlığın için ücretsiz, reklamsız ve açık kaynak çalışma takibi. Verilerin cihazında kalır."
      actions={
        <Button size="large" fullWidth onClick={onNext}>
          Başla
        </Button>
      }
    >
      <ul className="border-t border-separator">
        {HIGHLIGHTS.map((item) => (
          <li key={item.title} className="border-b border-separator py-5">
            <p className="text-headline">{item.title}</p>
            <p className="mt-1 text-subheadline text-secondary-label">{item.text}</p>
          </li>
        ))}
      </ul>
    </OnboardingStepLayout>
  )
}
