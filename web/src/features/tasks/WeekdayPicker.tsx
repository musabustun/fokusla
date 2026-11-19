import type { Weekday } from '@/domain'
import { cx } from '@/ui'
import { WEEKDAYS, weekdayLongName, weekdayShortName } from './format'

export interface WeekdayPickerProps {
  value: readonly Weekday[]
  onChange: (value: Weekday[]) => void
  invalid?: boolean
  /** Hata metninin id'si (`aria-describedby`). */
  describedBy?: string
}

/** Gün seçici: 7 aç/kapa düğmesi (Pzt…Paz). SwiftUI: `HStack` içinde `Toggle(.button)`. */
export function WeekdayPicker({ value, onChange, invalid, describedBy }: WeekdayPickerProps) {
  const toggle = (weekday: Weekday) => {
    const next = value.includes(weekday)
      ? value.filter((day) => day !== weekday)
      : [...value, weekday]
    onChange([...next].sort((a, b) => a - b))
  }

  return (
    <div
      role="group"
      aria-label="Günler"
      aria-describedby={describedBy}
      aria-invalid={invalid || undefined}
      className="grid grid-cols-7 gap-1.5"
    >
      {WEEKDAYS.map((weekday) => {
        const isSelected = value.includes(weekday)
        return (
          <button
            key={weekday}
            type="button"
            aria-pressed={isSelected}
            aria-label={weekdayLongName(weekday)}
            onClick={() => toggle(weekday)}
            className={cx(
              'flex min-h-11 min-w-0 items-center justify-center rounded-md text-subheadline transition-colors',
              isSelected
                ? 'bg-accent font-semibold text-accent-contrast'
                : 'bg-fill text-label active:opacity-70',
            )}
          >
            {weekdayShortName(weekday)}
          </button>
        )
      })}
    </div>
  )
}
