import type { ReactNode } from 'react'
import { ONBOARDING_STEPS, stepNumber, type OnboardingStep } from './onboardingFlow'

interface OnboardingStepLayoutProps {
  step: OnboardingStep
  title: string
  subtitle?: ReactNode
  /** Adım içeriği (ör. alan seçenekleri). */
  children?: ReactNode
  /** Alttaki eylem düğmeleri. */
  actions: ReactNode
}

/** Onboarding adımlarının ortak iskeleti: adım göstergesi, başlık, içerik, alt eylemler. */
export function OnboardingStepLayout({
  step,
  title,
  subtitle,
  children,
  actions,
}: OnboardingStepLayoutProps) {
  const current = stepNumber(step)
  return (
    <main
      id="main"
      className="flex min-h-dvh flex-col bg-background px-[max(1.5rem,env(safe-area-inset-left))] pt-[max(3rem,env(safe-area-inset-top))] pb-[max(1.5rem,env(safe-area-inset-bottom))] text-label md:items-center md:justify-center md:py-12"
    >
      <div className="flex w-full max-w-md flex-1 flex-col md:flex-none">
        <p className="text-footnote font-semibold text-secondary-label">
          <span className="sr-only">
            Adım {current} / {ONBOARDING_STEPS.length}
          </span>
          <span aria-hidden="true" className="flex gap-1.5">
            {ONBOARDING_STEPS.map((item, index) => (
              <span
                key={item}
                className={`h-1.5 w-8 rounded-full ${index < current ? 'bg-accent' : 'bg-fill'}`}
              />
            ))}
          </span>
        </p>
        <h1 className="mt-6 text-large-title">{title}</h1>
        {subtitle ? <div className="mt-3 text-body text-secondary-label">{subtitle}</div> : null}
        <div className="mt-8 flex-1">{children}</div>
        <div className="mt-8 flex flex-col gap-3">{actions}</div>
      </div>
    </main>
  )
}
