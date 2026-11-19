import { UserPlus } from 'lucide-react'
import { useState } from 'react'
import { useServices, type SocialFriend } from '@/data'
import type { PresenceState } from '@/domain'
import { effectivePresenceState, liveStateMs, liveTodayFocusMs } from '@/domain/calc/social'
import { Button, ListRow, ListSection, Sheet } from '@/ui'
import { formatDurationShort, formatPresenceLine } from './format'
import { PresenceDot } from './PresenceDot'
import { socialErrorMessage } from './socialErrors'

const STATE_ORDER: Record<PresenceState, number> = { focusing: 0, onBreak: 1, offline: 2 }

interface FriendsSectionProps {
  friends: readonly SocialFriend[]
  now: Date
  onAddFriend: () => void
}

/** Arkadaş listesi: odakta → molada → çevrimdışı; bugünkü toplam süre. */
export function FriendsSection({ friends, now, onAddFriend }: FriendsSectionProps) {
  // Kimlik tutulur; sayfa canlı listeden okunur (durum güncellemeleri sayfaya da yansır).
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const selected = friends.find((friend) => friend.userId === selectedId) ?? null
  const rows = friends
    .map((friend) => ({ friend, state: effectivePresenceState(friend.presence, now) }))
    .sort((a, b) => STATE_ORDER[a.state] - STATE_ORDER[b.state])
  const focusingCount = rows.filter((row) => row.state === 'focusing').length

  return (
    <>
      <ListSection
        header={`Arkadaşlar (${friends.length})`}
        footer={
          friends.length === 0
            ? 'Henüz arkadaşın yok. Kullanıcı adı ya da davet koduyla ekleyebilirsin.'
            : `${focusingCount} arkadaşın şu an odakta. Sağdaki süre bugünkü toplam odak süresidir.`
        }
      >
        <ListRow
          title="Arkadaş ekle"
          icon={<UserPlus className="size-5.5" />}
          onClick={onAddFriend}
          chevron={false}
        />
        {rows.map(({ friend, state }) => (
          <ListRow
            key={friend.userId}
            title={
              <span className="flex items-center gap-2">
                <PresenceDot state={state} />
                <span className="truncate">@{friend.username}</span>
              </span>
            }
            subtitle={formatPresenceLine(state, liveStateMs(friend.presence, now))}
            value={
              <span className="tabular-nums">
                <span className="sr-only">Bugün </span>
                {formatDurationShort(liveTodayFocusMs(friend.presence, now))}
              </span>
            }
            onClick={() => setSelectedId(friend.userId)}
          />
        ))}
      </ListSection>
      <FriendSheet friend={selected} onClose={() => setSelectedId(null)} now={now} />
    </>
  )
}

interface FriendSheetProps {
  friend: SocialFriend | null
  onClose: () => void
  now: Date
}

function FriendSheet({ friend, onClose, now }: FriendSheetProps) {
  const { social } = useServices()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleRemove(userId: string) {
    setBusy(true)
    setError(null)
    try {
      await social.removeFriend(userId)
      onClose()
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  const state = friend ? effectivePresenceState(friend.presence, now) : 'offline'
  return (
    <Sheet
      open={friend !== null}
      onClose={() => {
        setError(null)
        onClose()
      }}
      title={friend ? `@${friend.username}` : 'Arkadaş'}
      footer={
        friend && (
          <Button
            variant="destructive"
            fullWidth
            loading={busy}
            onClick={() => handleRemove(friend.userId)}
          >
            Arkadaşlıktan çıkar
          </Button>
        )
      }
    >
      {friend && (
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-body">
          <dt className="text-secondary-label">Durum</dt>
          <dd className="flex items-center gap-2">
            <PresenceDot state={state} />
            {formatPresenceLine(state, liveStateMs(friend.presence, now))}
          </dd>
          <dt className="text-secondary-label">Bugün</dt>
          <dd className="tabular-nums">
            {formatDurationShort(liveTodayFocusMs(friend.presence, now))}
          </dd>
        </dl>
      )}
      {error && (
        <p role="alert" className="mt-3 text-subheadline text-danger">
          {error}
        </p>
      )}
    </Sheet>
  )
}
