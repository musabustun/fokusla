import { useCurrentProfile } from '@/data'
import { greetingKey, type GreetingKey } from '@/domain/calc/today'
import { FIELD_LABELS } from '@/curriculum'
import { ScreenHeader } from '@/ui'

const GREETINGS: Readonly<Record<GreetingKey, string>> = {
  morning: 'Günaydın',
  afternoon: 'İyi günler',
  evening: 'İyi akşamlar',
  night: 'İyi geceler',
}

const DATE_FORMAT = new Intl.DateTimeFormat('tr-TR', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
})

export interface TodayHeaderProps {
  now: Date
}

/** Büyük başlık: tarih, kısa selam ve kullanıcının YKS alanı. */
export function TodayHeader({ now }: TodayHeaderProps) {
  const state = useCurrentProfile()
  const profile = state.status === 'ready' ? state.profile : undefined
  const name = profile?.displayName?.trim()
  const greeting = `${GREETINGS[greetingKey(now)]}${name ? `, ${name}` : ''}`
  return (
    <ScreenHeader
      title="Bugün"
      subtitle={
        <>
          <span className="block">{DATE_FORMAT.format(now)}</span>
          <span className="mt-1 flex flex-wrap items-center gap-2">
            <span>{greeting}</span>
            {profile && (
              <span className="rounded-full bg-accent-subtle px-2.5 py-0.5 text-footnote font-semibold text-accent-ink">
                {FIELD_LABELS[profile.field]}
                <span className="sr-only"> alanı</span>
              </span>
            )}
          </span>
        </>
      }
    />
  )
}
