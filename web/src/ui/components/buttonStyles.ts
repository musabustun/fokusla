import { cx } from '../cx'

/**
 * - `filled`: ana eylem — kehribar hap (ekranda bir tane).
 * - `tinted`: ikincil eylem — çizgili hap (1px `separator-strong` sınır).
 * - `plain`: sessiz, nötr metin eylemi (araç çubuğu, "Tümü", geri) — kehribar değil.
 * - `destructive`: yıkıcı eylem — kırmızı çizgili hap.
 */
export type ButtonVariant = 'filled' | 'tinted' | 'plain' | 'destructive'
export type ButtonSize = 'small' | 'medium' | 'large'

export interface ButtonStyleOptions {
  variant?: ButtonVariant
  size?: ButtonSize
  fullWidth?: boolean
}

// Basınca hafif küçülme (scale 0.97, 120ms); renk geçişleri 200ms. Hareket azaltmada durur.
const BASE = [
  'inline-flex min-h-11 min-w-11 items-center justify-center gap-2 rounded-full font-semibold select-none',
  'transition-[transform,background-color,border-color,color,opacity] duration-200 ease-standard',
  'active:scale-97 active:duration-100 motion-reduce:active:scale-100',
  'disabled:cursor-not-allowed disabled:opacity-40 disabled:active:scale-100 aria-busy:cursor-progress',
].join(' ')

const VARIANTS: Record<ButtonVariant, string> = {
  filled: 'bg-accent text-accent-contrast hover:opacity-90',
  tinted: 'border border-separator-strong text-label hover:bg-fill',
  plain: 'text-label hover:bg-fill',
  destructive: 'border border-danger text-danger hover:bg-danger-subtle',
}

const SIZES: Record<ButtonSize, string> = {
  small: 'px-3.5 text-subheadline',
  medium: 'px-5 text-callout',
  large: 'min-h-14 px-7 text-headline',
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
