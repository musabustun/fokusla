import { Apple } from 'lucide-react'
import { cx } from '../cx'

export interface AppleSignInButtonProps {
  onClick: () => void
  /** Giriş sürerken: devre dışı + `aria-busy` + "Giriş yapılıyor…". */
  loading?: boolean
  disabled?: boolean
  /** Varsayılan: "Apple ile Giriş". */
  label?: string
  className?: string
}

/**
 * Apple'ın arayüz yönergelerine yakın "Apple ile Giriş" düğmesi: açık temada siyah, koyu temada
 * beyaz (label/background tokenları). Native: `SignInWithAppleButton` (AuthenticationServices).
 */
export function AppleSignInButton({
  onClick,
  loading = false,
  disabled = false,
  label = 'Apple ile Giriş',
  className,
}: AppleSignInButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cx(
        'inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-md bg-label px-5 text-headline text-background transition-opacity',
        'disabled:cursor-not-allowed disabled:opacity-60',
        className,
      )}
    >
      <Apple className="size-5" aria-hidden="true" />
      {loading ? 'Giriş yapılıyor…' : label}
    </button>
  )
}
