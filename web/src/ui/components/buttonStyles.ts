import { cx } from '../cx'

export type ButtonVariant = 'filled' | 'tinted' | 'plain' | 'destructive'
export type ButtonSize = 'small' | 'medium' | 'large'

export interface ButtonStyleOptions {
  variant?: ButtonVariant
  size?: ButtonSize
  fullWidth?: boolean
}

const BASE =
  'inline-flex min-h-11 min-w-11 items-center justify-center gap-2 rounded-md font-semibold transition-opacity select-none active:opacity-70 disabled:cursor-not-allowed disabled:opacity-40 aria-busy:cursor-progress'

const VARIANTS: Record<ButtonVariant, string> = {
  filled: 'bg-accent text-accent-contrast',
  tinted: 'bg-accent-subtle text-accent',
  plain: 'bg-transparent text-accent',
  destructive: 'bg-danger-subtle text-danger',
}

const SIZES: Record<ButtonSize, string> = {
  small: 'px-3 text-subheadline',
  medium: 'px-4 text-body',
  large: 'min-h-13 rounded-lg px-5 text-headline',
}

/**
 * Button görünümünü bir `<a>`/`<Link>` gibi başka bir öğeye uygulamak için sınıf üretir:
 * `<Link to={ROUTES.focus} className={buttonStyles({ variant: 'filled' })}>`.
 */
export function buttonStyles({
  variant = 'filled',
  size = 'medium',
  fullWidth = false,
}: ButtonStyleOptions = {}): string {
  return cx(BASE, VARIANTS[variant], SIZES[size], fullWidth && 'w-full')
}
