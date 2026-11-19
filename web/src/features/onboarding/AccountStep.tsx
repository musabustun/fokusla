import { Apple } from 'lucide-react'
import { Button, cx } from '@/ui'
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

interface AppleSignInButtonProps {
  loading: boolean
  disabled: boolean
  onClick: () => void
}

/**
 * Apple'ın arayüz yönergelerine yakın giriş düğmesi: açık temada siyah, koyu temada beyaz.
 * Native uygulamada ASAuthorizationAppleIDButton / SignInWithAppleButton kullanılacak.
 */
function AppleSignInButton({ loading, disabled, onClick }: AppleSignInButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-busy={loading || undefined}
      className={cx(
        'inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-md bg-label px-5 text-headline text-background transition-opacity',
        'disabled:cursor-not-allowed disabled:opacity-60',
      )}
    >
      <Apple className="size-5" aria-hidden="true" />
      {loading ? 'Giriş yapılıyor…' : 'Apple ile Giriş'}
    </button>
  )
}
