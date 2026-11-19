import { LoaderCircle } from 'lucide-react'
import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cx } from '../cx'
import { buttonStyles, type ButtonSize, type ButtonVariant } from './buttonStyles'

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
  fullWidth?: boolean
  /** true iken buton devre dışı kalır, `aria-busy` alır ve bir dönen gösterge görünür. */
  loading?: boolean
  /** Etiketin solundaki ikon (lucide-react, `aria-hidden`). */
  icon?: ReactNode
}

export function Button({
  variant,
  size,
  fullWidth,
  loading = false,
  icon,
  disabled,
  type = 'button',
  className,
  children,
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cx(buttonStyles({ variant, size, fullWidth }), className)}
      {...rest}
    >
      {loading ? (
        <LoaderCircle aria-hidden className="size-[1.1em] motion-safe:animate-spin" />
      ) : (
        icon
      )}
      {children}
    </button>
  )
}
