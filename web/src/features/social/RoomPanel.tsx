import { DoorOpen } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useServices, type RoomSummary, type SocialRoom } from '@/data'
import type { SocialPresence } from '@/domain'
import { effectivePresenceState, liveSessionMs, liveStateMs } from '@/domain/calc/social'
import { Button, buttonStyles, Card, Metric } from '@/ui'
import { formatClock, formatClockLabel, formatPresenceLine } from './format'
import { PresenceDot } from './PresenceDot'
import { CreateRoomSheet, JoinRoomSheet } from './RoomSheets'
import { socialErrorMessage } from './socialErrors'
import { useCopyFeedback } from './useCopyFeedback'

interface RoomPanelProps {
  room: SocialRoom | null
  friendRooms: readonly RoomSummary[]
  ownPresence: SocialPresence | null
  now: Date
}

/** Paralel odak: içindeysem oda, değilsem oda oluştur / katıl. */
export function RoomPanel({ room, friendRooms, ownPresence, now }: RoomPanelProps) {
  if (room) return <RoomView room={room} ownPresence={ownPresence} now={now} />
  return <RoomLobby friendRooms={friendRooms} />
}

function RoomLobby({ friendRooms }: { friendRooms: readonly RoomSummary[] }) {
  const { social } = useServices()
  const [sheet, setSheet] = useState<'create' | 'join' | null>(null)
  const [joiningId, setJoiningId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function handleJoin(roomId: string) {
    setJoiningId(roomId)
    setError(null)
    try {
      await social.joinRoom({ kind: 'room', roomId })
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setJoiningId(null)
    }
  }

  return (
    <>
      <Card title="Paralel odak" className="mb-10">
        <p className="mb-4 text-footnote text-secondary-label">
          Odada herkes kendi kronometresiyle çalışır; yalnızca durumlar ve süreler görünür.
        </p>
        <div className="flex flex-wrap gap-2">
          <Button variant="tinted" onClick={() => setSheet('create')}>
            Oda oluştur
          </Button>
          <Button variant="plain" onClick={() => setSheet('join')}>
            Kodla katıl
          </Button>
        </div>
      </Card>
      <section aria-labelledby="friend-rooms-heading" className="mb-10">
        <h2 id="friend-rooms-heading" className="mb-2 eyebrow">
          Arkadaşlarının odaları
        </h2>
        {friendRooms.length === 0 ? (
          <p className="border-y border-separator py-3 text-subheadline text-secondary-label">
            Şu an açık oda yok. Bir oda oluşturup arkadaşlarını çağırabilirsin.
          </p>
        ) : (
          <ul role="list" className="border-y border-separator">
            {friendRooms.map((summary) => (
              <li
                key={summary.id}
                className="flex min-h-13 items-center gap-3 py-2.5 not-first:border-t not-first:border-separator"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-body">{summary.name}</p>
                  <p className="text-subheadline text-secondary-label">
                    @{summary.host.username} · {summary.memberCount} kişi · {summary.focusingCount}{' '}
                    odakta
                  </p>
                </div>
                <Button
                  size="small"
                  variant="tinted"
                  loading={joiningId === summary.id}
                  aria-label={`${summary.name} odasına katıl`}
                  onClick={() => handleJoin(summary.id)}
                >
                  Katıl
                </Button>
              </li>
            ))}
          </ul>
        )}
        {error && (
          <p role="alert" className="mt-2 text-footnote text-danger">
            {error}
          </p>
        )}
      </section>
      <CreateRoomSheet open={sheet === 'create'} onClose={() => setSheet(null)} />
      <JoinRoomSheet open={sheet === 'join'} onClose={() => setSheet(null)} />
    </>
  )
}

interface RoomViewProps {
  room: SocialRoom
  ownPresence: SocialPresence | null
  now: Date
}

function RoomView({ room, ownPresence, now }: RoomViewProps) {
  const { social } = useServices()
  const [leaving, setLeaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { copied, copy } = useCopyFeedback()
  const self = room.members.find((member) => member.isSelf)
  const isHost = self?.isHost ?? false
  const ownState = effectivePresenceState(ownPresence, now)
  const memberStates = room.members.map((member) => {
    const presence = member.isSelf ? ownPresence : member.presence
    return { state: effectivePresenceState(presence, now), sessionMs: liveSessionMs(presence, now) }
  })
  const focusingCount = memberStates.filter((m) => m.state === 'focusing').length
  const roomMs = Math.max(0, ...memberStates.map((m) => m.sessionMs))

  async function handleLeave() {
    setLeaving(true)
    setError(null)
    try {
      await social.leaveRoom()
    } catch (caught) {
      setError(socialErrorMessage(caught))
      setLeaving(false)
    }
  }

  return (
    <Card
      title={room.name}
      className="mb-10"
      trailing={<DoorOpen aria-hidden className="size-5 text-secondary-label" />}
    >
      <div className="mb-6 grid grid-cols-3 gap-4">
        <Metric label="Katılımcı" value={room.members.length} size="lg" />
        <Metric label="Odakta" value={focusingCount} size="lg" tone="success" />
        <Metric label="Oda süresi" value={formatClock(roomMs)} size="lg" />
      </div>
      <div className="mb-6 flex items-center justify-between gap-3 border-y border-separator py-2">
        <div className="min-w-0">
          <p className="eyebrow">Oda davet kodu</p>
          <p className="tracking-widest numeric text-numeral-sm">{room.inviteCode}</p>
        </div>
        <Button
          size="small"
          variant="plain"
          onClick={() => copy('room', room.inviteCode)}
          aria-label="Oda davet kodunu kopyala"
        >
          {copied === 'room' ? 'Kopyalandı' : 'Kopyala'}
        </Button>
      </div>

      <h3 className="mb-1.5 eyebrow">Odadakiler ({room.members.length})</h3>
      <ul role="list" aria-label="Odadakiler" className="mb-4">
        {room.members.map((member) => {
          const presence = member.isSelf ? ownPresence : member.presence
          const state = effectivePresenceState(presence, now)
          const sessionMs = liveSessionMs(presence, now)
          return (
            <li
              key={member.userId}
              className="flex min-h-11 items-center gap-3 py-2 not-first:border-t not-first:border-separator"
            >
              <PresenceDot state={state} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-body">
                  @{member.username}
                  {member.isSelf && <span className="text-secondary-label"> (sen)</span>}
                  {member.isHost && (
                    <span className="ml-1.5 rounded-sm bg-accent-subtle px-1.5 py-0.5 text-caption text-accent-ink">
                      Ev sahibi
                    </span>
                  )}
                </p>
                <p className="text-subheadline text-secondary-label">
                  {formatPresenceLine(state, liveStateMs(presence, now))}
                </p>
              </div>
              {state !== 'offline' && (
                <span
                  className="numeric text-numeral-sm"
                  aria-label={`Oturum ${formatClockLabel(sessionMs)}`}
                >
                  {formatClock(sessionMs)}
                </span>
              )}
            </li>
          )
        })}
      </ul>

      <div className="flex flex-col gap-2">
        <p className="text-footnote text-secondary-label">
          {ownState === 'offline'
            ? 'Henüz başlamadın. Kronometreni Odak ekranında başlat; durumun burada görünür.'
            : 'Süren Odak ekranındaki kronometreden gelir.'}
        </p>
        <Link to={ROUTES.focus} className={buttonStyles({ variant: 'tinted', fullWidth: true })}>
          Odak'a git
        </Link>
        <Button variant="destructive" fullWidth loading={leaving} onClick={handleLeave}>
          {isHost ? 'Odayı kapat' : 'Odadan çık'}
        </Button>
        {error && (
          <p role="alert" className="text-footnote text-danger">
            {error}
          </p>
        )}
      </div>
      <p aria-live="polite" className="sr-only">
        {copied ? 'Panoya kopyalandı' : ''}
      </p>
    </Card>
  )
}
