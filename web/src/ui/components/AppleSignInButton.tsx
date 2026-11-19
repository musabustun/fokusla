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
        'inline-flex min-h-13 w-full items-center justify-center gap-2 rounded-full bg-label px-6 text-headline text-background',
        'transition-[transform,opacity] duration-200 ease-standard hover:opacity-90 active:scale-97 motion-reduce:active:scale-100',
        'disabled:cursor-not-allowed disabled:opacity-60 disabled:active:scale-100',
        className,
      )}
    >
      <Apple className="size-5" aria-hidden="true" />
      {loading ? 'Giriş yapılıyor…' : label}
    </button>
  )
}
