import { BookOpen, ChartColumn, Timer } from 'lucide-react'
import type { ReactNode } from 'react'
import { Button } from '@/ui'
import { OnboardingStepLayout } from './OnboardingStepLayout'

interface WelcomeStepProps {
  onNext: () => void
}

interface Highlight {
  icon: ReactNode
  title: string
  text: string
}

const ICON_CLASS = 'size-6 shrink-0 text-accent-ink'

const HIGHLIGHTS: readonly Highlight[] = [
  {
    icon: <Timer className={ICON_CLASS} aria-hidden="true" />,
    title: 'Odaklan',
    text: 'Kronometreyle çalış, molalarını ve günlük toplamını gör.',
  },
  {
    icon: <ChartColumn className={ICON_CLASS} aria-hidden="true" />,
    title: 'Analiz et',
    text: 'Konu konu testlerini, doğru-yanlışlarını ve netlerini takip et.',
  },
  {
    icon: <BookOpen className={ICON_CLASS} aria-hidden="true" />,
    title: 'Planla',
    text: 'Kitaplarında nerede kaldığını, rutinlerini ve ödevlerini tut.',
  },
]

export function WelcomeStep({ onNext }: WelcomeStepProps) {
  return (
    <OnboardingStepLayout
      step="welcome"
      title="Fokus'a hoş geldin"
      subtitle="YKS hazırlığın için ücretsiz, reklamsız ve açık kaynak çalışma takibi. Verilerin cihazında kalır."
      actions={
        <Button size="large" fullWidth onClick={onNext}>
          Başla
        </Button>
      }
    >
      <ul className="flex flex-col gap-5">
        {HIGHLIGHTS.map((item) => (
          <li key={item.title} className="flex gap-4">
            {item.icon}
            <div>
              <p className="text-headline">{item.title}</p>
              <p className="text-subheadline text-secondary-label">{item.text}</p>
            </div>
          </li>
        ))}
      </ul>
    </OnboardingStepLayout>
  )
}
