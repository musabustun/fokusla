import { Timer } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import type { SocialPresence } from '@/domain'
import { liveStateMs, liveTodayFocusMs } from '@/domain/calc/social'
import { ListRow, ListSection } from '@/ui'
import { formatDurationShort, formatPresenceLine } from './format'
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
  return (
    <ListSection
      header="Senin durumun"
      footer={
        isDiscoverable
          ? 'Kronometreni Odak ekranından başlat; durumun arkadaşlarına otomatik yansır.'
          : 'Gizli olduğun için durumun kimseyle paylaşılmıyor.'
      }
    >
      <ListRow
        title={
          <span className="flex items-center gap-2">
            <PresenceDot state={state} />
            {line}
          </span>
        }
        subtitle={`Bugün ${formatDurationShort(liveTodayFocusMs(presence, now))}`}
        icon={<Timer className="size-5.5" />}
        value="Odak'a git"
        render={(props) => <Link to={ROUTES.focus} {...props} />}
      />
    </ListSection>
  )
}
