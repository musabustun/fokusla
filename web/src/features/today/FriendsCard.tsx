import { ROUTES } from '@/app/routes'
import { useNow, useSocialSnapshot, type SocialFriend } from '@/data'
import type { ISODate } from '@/domain'
import { focusingFriends } from '@/domain/calc/today'
import { CardEmpty, TodayCard } from './TodayCard'
import { formatInteger } from './format'

export interface FriendsCardProps {
  today: ISODate
  className?: string
}

const TITLE = 'Arkadaşlar'
/** Arkadaş durumu gecikmeli gelir; bayatlık kontrolü için 30 sn yeterli. */
const NOW_REFRESH_MS = 30_000
/** Kartta adı gösterilen en fazla odaktaki arkadaş. */
const VISIBLE_FRIEND_LIMIT = 5

/**
 * Odaktaki arkadaşlar: "Şu an N arkadaşın odakta" + en fazla 5 "@ad" etiketi.
 * Gizlilik: yalnızca kullanıcı adı ve odak durumu gösterilir.
 */
function FocusingFriends({ friends }: { friends: readonly SocialFriend[] }) {
  const now = useNow(NOW_REFRESH_MS)
  const focusing = focusingFriends(friends, now)

  if (focusing.length === 0) {
    return <p className="text-callout text-secondary-label">Şu an odakta arkadaşın yok.</p>
  }

  const visible = focusing.slice(0, VISIBLE_FRIEND_LIMIT)
  const hiddenCount = focusing.length - visible.length
  return (
    <div className="flex flex-col gap-3">
      <p className="text-callout">Şu an {formatInteger(focusing.length)} arkadaşın odakta</p>
      <ul aria-label="Odaktaki arkadaşlar" className="flex flex-wrap gap-2">
        {visible.map((friend) => (
          <li
            key={friend.userId}
            className="flex max-w-full items-center gap-1.5 rounded-full bg-accent-subtle px-3 py-1 text-subheadline text-accent"
          >
            <span aria-hidden="true" className="size-2 shrink-0 rounded-full bg-success" />
            <span className="truncate">@{friend.username}</span>
          </li>
        ))}
      </ul>
      {hiddenCount > 0 && (
        <p className="text-footnote text-secondary-label">
          ve {formatInteger(hiddenCount)} kişi daha
        </p>
      )}
    </div>
  )
}

/** Arkadaşlar: girişsiz/kullanıcı adsız davet, hazırsa şu an odakta olan arkadaşlar. */
export function FriendsCard({ className }: FriendsCardProps) {
  const snapshot = useSocialSnapshot()

  switch (snapshot.status) {
    case 'loading':
      return null
    case 'signedOut':
      return (
        <TodayCard title={TITLE} className={className}>
          <CardEmpty
            message="Arkadaşlarınla aynı anda odaklan."
            actionLabel="Sosyal'e göz at"
            to={ROUTES.social}
          />
        </TodayCard>
      )
    case 'needsUsername':
      return (
        <TodayCard title={TITLE} className={className}>
          <CardEmpty
            message="Sosyal için bir kullanıcı adı seç."
            actionLabel="Kullanıcı adı seç"
            to={ROUTES.social}
          />
        </TodayCard>
      )
    case 'ready':
      if (snapshot.friends.length === 0) {
        return (
          <TodayCard title={TITLE} className={className}>
            <CardEmpty
              message="Henüz arkadaşın yok."
              actionLabel="Arkadaş ekle"
              to={ROUTES.social}
            />
          </TodayCard>
        )
      }
      return (
        <TodayCard
          title={TITLE}
          linkTo={ROUTES.social}
          linkLabel="Sosyal ekranı"
          className={className}
        >
          <FocusingFriends friends={snapshot.friends} />
        </TodayCard>
      )
  }
}
