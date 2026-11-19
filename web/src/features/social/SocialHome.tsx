import { useState } from 'react'
import { useSearchParams } from 'react-router'
import type { SocialSnapshot } from '@/data'
import { ownPresenceFromFocus } from '@/domain/calc/social'
import { AddFriendSheet, type AddFriendMode } from './AddFriendSheet'
import { FriendsSection } from './FriendsSection'
import { useNow, useOwnFocusSnapshot, usePublishOwnPresence } from './hooks'
import { OwnStatusSection } from './OwnStatusSection'
import { ProfileSection } from './ProfileSection'
import { RequestsSection } from './RequestsSection'
import { RoomPanel } from './RoomPanel'

/** Davet bağlantısındaki sorgu parametresi (`/sosyal?davet=KOD`). */
export const INVITE_QUERY_PARAM = 'davet'

interface AddFriendState {
  mode: AddFriendMode
  value: string
}

/**
 * Hazır sosyal ekranı. iPhone: tek sütun (oda üstte). iPad (≥1024px): solda istekler,
 * arkadaşlar ve profil; sağda oda (yan yana).
 */
export function SocialHome({ snapshot }: { snapshot: SocialSnapshot }) {
  const profile = snapshot.profile
  const now = useNow()
  const focus = useOwnFocusSnapshot()
  usePublishOwnPresence(focus, profile?.isDiscoverable ?? false)
  const ownPresence = focus ? ownPresenceFromFocus(focus, now) : null

  const [searchParams, setSearchParams] = useSearchParams()
  const invitedCode = searchParams.get(INVITE_QUERY_PARAM)
  const [addFriend, setAddFriend] = useState<AddFriendState | null>(() =>
    invitedCode ? { mode: 'inviteCode', value: invitedCode } : null,
  )

  function closeAddFriend() {
    setAddFriend(null)
    if (invitedCode) {
      const next = new URLSearchParams(searchParams)
      next.delete(INVITE_QUERY_PARAM)
      setSearchParams(next, { replace: true })
    }
  }

  if (!profile) return null

  return (
    <div className="flex flex-col lg:grid lg:grid-cols-2 lg:items-start lg:gap-x-10">
      <div className="order-2 lg:order-1">
        <RequestsSection requests={snapshot.requests} />
        <FriendsSection
          friends={snapshot.friends}
          now={now}
          onAddFriend={() => setAddFriend({ mode: 'username', value: '' })}
        />
        <ProfileSection profile={profile} />
      </div>
      <div className="order-1 lg:sticky lg:top-6 lg:order-2">
        <RoomPanel
          room={snapshot.room}
          friendRooms={snapshot.friendRooms}
          ownPresence={ownPresence}
          now={now}
        />
        <OwnStatusSection
          presence={ownPresence}
          now={now}
          isDiscoverable={profile.isDiscoverable}
        />
      </div>
      <AddFriendSheet
        key={addFriend ? `${addFriend.mode}:${addFriend.value}` : 'closed'}
        open={addFriend !== null}
        onClose={closeAddFriend}
        initialMode={addFriend?.mode}
        initialValue={addFriend?.value}
      />
    </div>
  )
}
