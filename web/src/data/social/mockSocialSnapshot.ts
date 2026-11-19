/**
 * MockSocialService'in saklanan hesap + simüle dünya durumundan SocialSnapshot üreten saf
 * fonksiyonları. Her çağrı YENİ nesneler döner; girdiler değiştirilmez.
 */
import { effectivePresenceState } from '@/domain/calc/social'
import type { SocialPresence } from '@/domain'
import type { StoredAccount, StoredFriend } from './mockSocialStore'
import {
  findSimulatedUserById,
  minutesBefore,
  SIMULATED_ROOMS,
  type SimulatedRoom,
} from './simulatedUsers'
import type {
  RoomMember,
  RoomSummary,
  SocialFriend,
  SocialRoom,
  SocialSnapshot,
  SocialStatus,
} from './SocialService'

export type PresenceMap = ReadonlyMap<string, SocialPresence>

export interface SnapshotInput {
  status: SocialStatus
  account: StoredAccount | null
  presences: PresenceMap
  /** Simüle odaların oluşturulma/katılma zamanlarının referans anı. */
  worldStartedAt: Date
  now: Date
}

export function emptySnapshot(status: SocialStatus): SocialSnapshot {
  return { status, profile: null, friends: [], requests: [], room: null, friendRooms: [] }
}

const byUsername = (a: { username: string }, b: { username: string }) =>
  a.username.localeCompare(b.username, 'tr')

/** Arkadaşlar kullanıcı adına göre (Türkçe sıralama). */
export function sortFriends<T extends StoredFriend>(friends: readonly T[]): T[] {
  return [...friends].sort(byUsername)
}

/** Ev sahibi önce, sonra katılma zamanına göre. */
function sortMembers(members: readonly RoomMember[]): RoomMember[] {
  return [...members].sort(
    (a, b) => Number(b.isHost) - Number(a.isHost) || a.joinedAt.localeCompare(b.joinedAt),
  )
}

const presenceOf = (presences: PresenceMap, userId: string): SocialPresence | null =>
  presences.get(userId) ?? null

function simulatedMember(
  userId: string,
  hostUserId: string,
  joinedAt: string,
  presences: PresenceMap,
): RoomMember | null {
  const simulated = findSimulatedUserById(userId)
  if (!simulated) return null
  return {
    userId,
    username: simulated.username,
    isSelf: false,
    isHost: userId === hostUserId,
    presence: presenceOf(presences, userId),
    joinedAt,
  }
}

function simulatedRoomMembers(
  room: SimulatedRoom,
  presences: PresenceMap,
  worldStartedAt: Date,
): RoomMember[] {
  return room.members
    .map((m) =>
      simulatedMember(
        m.userId,
        room.hostUserId,
        minutesBefore(worldStartedAt, m.joinedMinutesAgo),
        presences,
      ),
    )
    .filter((m): m is RoomMember => m !== null)
}

function buildRoom(
  account: StoredAccount,
  presences: PresenceMap,
  worldStartedAt: Date,
): SocialRoom | null {
  const stored = account.room
  if (!stored) return null
  const { profile, selfPresence } = account
  const self = (isHost: boolean, joinedAt: string): RoomMember => ({
    userId: profile.userId,
    username: profile.username,
    isSelf: true,
    isHost,
    presence: selfPresence,
    joinedAt,
  })

  if (stored.kind === 'hosted') {
    const guests = stored.guests
      .map((g) => simulatedMember(g.userId, profile.userId, g.joinedAt, presences))
      .filter((m): m is RoomMember => m !== null)
    return {
      id: stored.id,
      name: stored.name,
      hostUserId: profile.userId,
      inviteCode: stored.inviteCode,
      members: sortMembers([self(true, stored.createdAt), ...guests]),
      createdAt: stored.createdAt,
    }
  }

  const simulated = SIMULATED_ROOMS.find((r) => r.id === stored.roomId)
  if (!simulated) return null
  return {
    id: simulated.id,
    name: simulated.name,
    hostUserId: simulated.hostUserId,
    inviteCode: simulated.inviteCode,
    members: sortMembers([
      ...simulatedRoomMembers(simulated, presences, worldStartedAt),
      self(false, stored.joinedAt),
    ]),
    createdAt: minutesBefore(worldStartedAt, simulated.createdMinutesAgo),
  }
}

function buildFriendRooms(
  account: StoredAccount,
  currentRoomId: string | null,
  presences: PresenceMap,
  now: Date,
): RoomSummary[] {
  const friendIds = new Set(account.friends.map((f) => f.userId))
  return SIMULATED_ROOMS.filter((r) => friendIds.has(r.hostUserId) && r.id !== currentRoomId)
    .map((room): RoomSummary | null => {
      const host = findSimulatedUserById(room.hostUserId)
      if (!host) return null
      const focusingCount = room.members.filter(
        (m) => effectivePresenceState(presenceOf(presences, m.userId), now) === 'focusing',
      ).length
      return {
        id: room.id,
        name: room.name,
        host: { userId: host.userId, username: host.username },
        memberCount: room.members.length,
        focusingCount,
      }
    })
    .filter((r): r is RoomSummary => r !== null)
}

export function buildSnapshot(input: SnapshotInput): SocialSnapshot {
  const { status, account, presences, worldStartedAt, now } = input
  if (status !== 'ready' || !account) return emptySnapshot(status)

  const friends: SocialFriend[] = sortFriends(account.friends).map((f) => ({
    userId: f.userId,
    username: f.username,
    presence: presenceOf(presences, f.userId),
    friendsSince: f.friendsSince,
  }))
  const requests = [...account.requests].sort((a, b) => b.createdAt.localeCompare(a.createdAt))
  const room = buildRoom(account, presences, worldStartedAt)

  return {
    status,
    profile: { ...account.profile },
    friends,
    requests,
    room,
    friendRooms: buildFriendRooms(account, room?.id ?? null, presences, now),
  }
}
