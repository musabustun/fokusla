import { Timer } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import type { SocialPresence } from '@/domain'
import {
  effectivePresenceState,
  liveSessionMs,
  liveStateMs,
  liveTodayFocusMs,
} from '@/domain/calc/social'
import { Card, ListRow, Metric } from '@/ui'
import { formatClock, formatDurationShort, formatPresenceLine } from './format'
import { PresenceDot } from './PresenceDot'

interface OwnStatusSectionProps {
  presence: SocialPresence | null
  now: Date
  isDiscoverable: boolean
}

/** Kendi durumum — focus verisinden yalnızca okunur; kronometre Odak ekranındadır. */
export function OwnStatusSection({ presence, now, isDiscoverable }: OwnStatusSectionProps) {
  const state = presence?.state ?? 'offline'
  const line = formatPresenceLine(state, liveStateMs(presence, now))
  const todayMs = liveTodayFocusMs(presence, now)
  const isFocusing = effectivePresenceState(presence, now) === 'focusing'
  return (
    <Card title="Senin durumun" className="mb-10">
      {isFocusing ? (
        <Metric
          label="Oturum"
          value={formatClock(liveSessionMs(presence, now))}
          size="xl"
          tone="success"
          caption={`Bugün ${formatDurationShort(todayMs)}`}
        />
      ) : (
        <Metric label="Bugün" value={formatDurationShort(todayMs)} size="lg" />
      )}
      <ul role="list" className="mt-4 border-y border-separator">
        <ListRow
          title={
            <span className="flex items-center gap-2">
              <PresenceDot state={state} />
              {line}
            </span>
          }
          icon={<Timer className="size-5.5" />}
          value="Odak'a git"
          render={(props) => <Link to={ROUTES.focus} {...props} />}
        />
      </ul>
      <p className="mt-2 text-footnote text-secondary-label">
        {isDiscoverable
          ? 'Kronometreni Odak ekranından başlat; durumun arkadaşlarına otomatik yansır.'
          : 'Gizli olduğun için durumun kimseyle paylaşılmıyor.'}
      </p>
    </Card>
  )
}
