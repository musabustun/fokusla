import { AppleSignInButton, Button } from '@/ui'
import { OnboardingStepLayout } from './OnboardingStepLayout'
import type { AccountChoice } from './useOnboarding'

interface AccountStepProps {
  pending: AccountChoice | null
  error: string | null
  onChoose: (choice: AccountChoice) => void
  onBack: () => void
}

export function AccountStep({ pending, error, onChoose, onBack }: AccountStepProps) {
  const isBusy = pending !== null
  return (
    <OnboardingStepLayout
      step="account"
      title="Verilerini yedekle"
      subtitle="Apple ile giriş yaparsan verilerini iCloud üzerinden iPhone ile iPad'in arasında eşitleyebilirsin. Giriş zorunlu değil; her şey cihazında çalışır."
      actions={
        <>
          {error ? (
            <p role="alert" className="text-subheadline text-danger">
              {error}
            </p>
          ) : null}
          <AppleSignInButton
            loading={pending === 'apple'}
            disabled={isBusy}
            onClick={() => onChoose('apple')}
          />
          <Button
            variant="tinted"
            size="large"
            fullWidth
            loading={pending === 'skip'}
            disabled={isBusy}
            onClick={() => onChoose('skip')}
          >
            Şimdilik atla
          </Button>
          <Button variant="plain" fullWidth disabled={isBusy} onClick={onBack}>
            Geri
          </Button>
        </>
      }
    />
  )
}
