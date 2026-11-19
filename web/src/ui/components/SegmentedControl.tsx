import { useRef, type KeyboardEvent } from 'react'
import { cx } from '../cx'

export interface SegmentedOption<T extends string> {
  value: T
  label: string
}

export interface SegmentedControlProps<T extends string> {
  options: readonly SegmentedOption<T>[]
  value: T
  onChange: (value: T) => void
  /** Zorunlu: grubun erişilebilir adı (ör. "Tema"). */
  'aria-label': string
  fullWidth?: boolean
  className?: string
}

const NEXT_KEYS = new Set(['ArrowRight', 'ArrowDown'])
const PREV_KEYS = new Set(['ArrowLeft', 'ArrowUp'])

function targetIndex(key: string, current: number, count: number): number | null {
  if (NEXT_KEYS.has(key)) return (current + 1) % count
  if (PREV_KEYS.has(key)) return (current - 1 + count) % count
  if (key === 'Home') return 0
  if (key === 'End') return count - 1
  return null
}

/** Hap biçimli segment seçici (seçili = ters renk); `radiogroup` semantiği ve ok tuşlarıyla gezinme (roving tabindex). */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  'aria-label': ariaLabel,
  fullWidth = false,
  className,
}: SegmentedControlProps<T>) {
  const buttonsRef = useRef<(HTMLButtonElement | null)[]>([])
  const selectedIndex = options.findIndex((option) => option.value === value)
  const focusableIndex = selectedIndex === -1 ? 0 : selectedIndex

  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const next = targetIndex(event.key, index, options.length)
    const option = next === null ? undefined : options[next]
    if (next === null || !option) return
    event.preventDefault()
    onChange(option.value)
    buttonsRef.current[next]?.focus()
  }

  return (
    <div
      role="radiogroup"
      aria-label={ariaLabel}
      className={cx(
        'inline-flex gap-0.5 rounded-full border border-separator p-0.5',
        fullWidth && 'flex w-full',
        className,
      )}
    >
      {options.map((option, index) => {
        const isSelected = index === selectedIndex
        return (
          <button
            key={option.value}
            ref={(element) => {
              buttonsRef.current[index] = element
            }}
            type="button"
            role="radio"
            aria-checked={isSelected}
            tabIndex={index === focusableIndex ? 0 : -1}
            onClick={() => onChange(option.value)}
            onKeyDown={(event) => handleKeyDown(event, index)}
            className={cx(
              'min-h-11 flex-1 rounded-full px-4 text-subheadline font-medium whitespace-nowrap',
              'transition-[background-color,color,transform] duration-200 ease-standard',
              'active:scale-97 motion-reduce:active:scale-100',
              isSelected
                ? 'bg-control-thumb font-semibold text-background'
                : 'text-secondary-label hover:bg-fill hover:text-label',
            )}
          >
            {option.label}
          </button>
        )
      })}
    </div>
  )
}
