import type { ReactNode } from 'react'
import { cx } from '@/ui'
import { ONBOARDING_STEPS, stepNumber, type OnboardingStep } from './onboardingFlow'

interface OnboardingStepLayoutProps {
  step: OnboardingStep
  title: string
  subtitle?: ReactNode
  /** Adım içeriği (ör. alan seçenekleri). */
  children?: ReactNode
  /** Alttaki eylem düğmeleri. */
  actions: ReactNode
  /** İlk ekran: marka satırı ve daha büyük başlık. */
  brand?: boolean
}

/** Onboarding adımlarının ortak iskeleti: adım göstergesi, başlık, içerik, alt eylemler. */
export function OnboardingStepLayout({
  step,
  title,
  subtitle,
  children,
  actions,
  brand = false,
}: OnboardingStepLayoutProps) {
  const current = stepNumber(step)
  const total = ONBOARDING_STEPS.length
  return (
    <main
      id="main"
      className="flex min-h-dvh flex-col bg-background px-[max(1.5rem,env(safe-area-inset-left))] pt-[max(3rem,env(safe-area-inset-top))] pb-[max(2rem,env(safe-area-inset-bottom))] text-label md:items-center md:justify-center md:py-16"
    >
      <div className="flex w-full max-w-md flex-1 flex-col md:flex-none">
        <div className="flex items-center justify-between">
          {brand ? (
            <p className="flex items-center gap-2 font-display text-headline">
              <span aria-hidden="true" className="size-2 rounded-full bg-accent" />
              Fokus
            </p>
          ) : (
            <span aria-hidden="true" />
          )}
          <p className="eyebrow">
            <span className="sr-only">
              Adım {current} / {total}
            </span>
            <span aria-hidden="true" className="numeric">
              {current} / {total}
            </span>
          </p>
        </div>
        <div aria-hidden="true" className="mt-4 flex gap-1.5">
          {ONBOARDING_STEPS.map((item, index) => (
            <span
              key={item}
              className={cx(
                'h-0.5 flex-1 rounded-full',
                index < current ? 'bg-accent' : 'bg-separator',
              )}
            />
          ))}
        </div>
        <h1
          className={cx('mt-12', brand ? 'text-large-title md:text-display' : 'text-large-title')}
        >
          {title}
        </h1>
        {subtitle ? <div className="mt-4 text-body text-secondary-label">{subtitle}</div> : null}
        <div className="mt-10 flex-1">{children}</div>
        <div className="mt-10 flex flex-col gap-3">{actions}</div>
      </div>
    </main>
  )
}
