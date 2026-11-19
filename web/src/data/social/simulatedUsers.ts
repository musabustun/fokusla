/**
 * MockSocialService'in sabit sahte dünyası: simüle edilen kullanıcılar, odaları ve durum
 * geçişleri. Saf veri + saf fonksiyonlar; zamanlayıcı ve depolama yoktur.
 *
 * Simüle kullanıcıların canlı durumu SAKLANMAZ: her açılışta `now`'a göre yeniden üretilir.
 */
import { toISODateTime, type PresenceState, type SocialPresence } from '@/domain'
import type { SocialUser } from './SocialService'

const MINUTE_MS = 60 * 1000

/** Simüle kullanıcı kimliği: `mock-user-<kullanıcı adı, . ve _ yerine ->`. */
export function simulatedUserId(username: string): string {
  return `mock-user-${username.replace(/[._]/g, '-')}`
}

interface InitialPresence {
  state: PresenceState
  /** Oturum başlangıcı (dakika önce); çevrimdışıysa null. */
  sessionStartedMinutesAgo: number | null
  /** Mevcut durumun başlangıcı (dakika önce); çevrimdışıysa null. */
  stateSinceMinutesAgo: number | null
  todayFocusMinutes: number
}

export interface SimulatedUser extends SocialUser {
  inviteCode: string
  initialPresence: InitialPresence
}

export interface SimulatedRoomMember {
  userId: string
  /** Dünyanın kurulduğu andan kaç dakika önce katıldı. */
  joinedMinutesAgo: number
}

export interface SimulatedRoom {
  id: string
  name: string
  inviteCode: string
  hostUserId: string
  createdMinutesAgo: number
  /** Ev sahibi dahil üyeler. */
  members: readonly SimulatedRoomMember[]
}

const user = (username: string, inviteCode: string, initialPresence: InitialPresence) =>
  ({ userId: simulatedUserId(username), username, inviteCode, initialPresence }) as const

export const SIMULATED_USERS: readonly SimulatedUser[] = [
  user('elif.say', 'ELIF42', {
    state: 'focusing',
    sessionStartedMinutesAgo: 70,
    stateSinceMinutesAgo: 25,
    todayFocusMinutes: 130,
  }),
  user('mert_ayt', 'MERT27', {
    state: 'onBreak',
    sessionStartedMinutesAgo: 50,
    stateSinceMinutesAgo: 4,
    todayFocusMinutes: 65,
  }),
  user('zeynep2027', 'ZEYNP7', {
    state: 'focusing',
    sessionStartedMinutesAgo: 15,
    stateSinceMinutesAgo: 15,
    todayFocusMinutes: 40,
  }),
  user('deniz_ea', 'DENIZ3', {
    state: 'focusing',
    sessionStartedMinutesAgo: 35,
    stateSinceMinutesAgo: 12,
    todayFocusMinutes: 200,
  }),
  user('can.tyt', 'CANTYT', {
    state: 'onBreak',
    sessionStartedMinutesAgo: 90,
    stateSinceMinutesAgo: 2,
    todayFocusMinutes: 100,
  }),
  user('ece_dil', 'ECEDIL', {
    state: 'offline',
    sessionStartedMinutesAgo: null,
    stateSinceMinutesAgo: null,
    todayFocusMinutes: 55,
  }),
]

export const SIMULATED_ROOMS: readonly SimulatedRoom[] = [
  {
    id: 'mock-room-sabah',
    name: 'Sabah kampı',
    inviteCode: 'SABAH1',
    hostUserId: simulatedUserId('elif.say'),
    createdMinutesAgo: 70,
    members: [
      { userId: simulatedUserId('elif.say'), joinedMinutesAgo: 70 },
      { userId: simulatedUserId('mert_ayt'), joinedMinutesAgo: 50 },
    ],
  },
  {
    id: 'mock-room-tytmat',
    name: 'TYT Matematik',
    inviteCode: 'TYTMAT',
    hostUserId: simulatedUserId('deniz_ea'),
    createdMinutesAgo: 35,
    members: [
      { userId: simulatedUserId('deniz_ea'), joinedMinutesAgo: 35 },
      { userId: simulatedUserId('can.tyt'), joinedMinutesAgo: 30 },
    ],
  },
]

/** Kimsenin alamayacağı kullanıcı adları. */
export const RESERVED_USERNAMES: readonly string[] = [
  'fokus',
  'admin',
  'destek',
  'yardim',
  'moderator',
]

/** İlk kullanıcı adı alındığında hazır gelen arkadaşlar. */
export const SEED_FRIEND_USERNAMES: readonly string[] = ['elif.say', 'mert_ayt']
/** İlk kullanıcı adı alındığında bekleyen gelen istekler. */
export const SEED_INCOMING_REQUEST_USERNAMES: readonly string[] = ['zeynep2027']

export const findSimulatedUserById = (userId: string): SimulatedUser | undefined =>
  SIMULATED_USERS.find((u) => u.userId === userId)

export const findSimulatedUserByUsername = (username: string): SimulatedUser | undefined =>
  SIMULATED_USERS.find((u) => u.username === username)

export const findSimulatedUserByInviteCode = (code: string): SimulatedUser | undefined =>
  SIMULATED_USERS.find((u) => u.inviteCode === code)

/** `now`'dan dakika önceki anın ISO zaman damgası. */
export const minutesBefore = (now: Date, minutes: number): string =>
  toISODateTime(new Date(now.getTime() - minutes * MINUTE_MS))

/** Simüle kullanıcının `now`'a göre başlangıç durumu. */
export function initialPresence(simulated: SimulatedUser, now: Date): SocialPresence {
  const initial = simulated.initialPresence
  const ago = (minutes: number | null) => (minutes === null ? null : minutesBefore(now, minutes))
  return {
    state: initial.state,
    sessionStartedAt: ago(initial.sessionStartedMinutesAgo),
    stateSince: ago(initial.stateSinceMinutesAgo),
    todayFocusMs: initial.todayFocusMinutes * MINUTE_MS,
    updatedAt: toISODateTime(now),
  }
}

// ---------------------------------------------------------------------------
// Simülasyon adımı
// ---------------------------------------------------------------------------

/**
 * Her simülasyon adımında (varsayılan 4 sn) durum geçiş olasılıkları. Ortalama odak bloğu
 * ≈ 3 dk, mola ≈ 40 sn: prototipte değişimler görülebilsin ama süreler anlamlı kalsın.
 */
export const TRANSITION_PROBABILITY = {
  focusingToBreak: 0.02,
  focusingToOffline: 0.002,
  breakToFocusing: 0.1,
  offlineToFocusing: 0.005,
} as const

/**
 * Tek bir rastgele sayıyla (0 ≤ r < 1) sonraki durumu seçer.
 * focusing: r < 0.02 → onBreak, 0.02 ≤ r < 0.022 → offline.
 */
export function nextPresenceState(state: PresenceState, r: number): PresenceState {
  const p = TRANSITION_PROBABILITY
  switch (state) {
    case 'focusing':
      if (r < p.focusingToBreak) return 'onBreak'
      return r < p.focusingToBreak + p.focusingToOffline ? 'offline' : 'focusing'
    case 'onBreak':
      return r < p.breakToFocusing ? 'focusing' : 'onBreak'
    case 'offline':
      return r < p.offlineToFocusing ? 'focusing' : 'offline'
  }
}

/**
 * Kalp atışı: çevrimiçi kullanıcının odak süresini `now`'a kadar biriktirir ve `updatedAt`'i
 * günceller. Çevrimdışı kullanıcı aynen döner.
 */
export function heartbeat(presence: SocialPresence, now: Date): SocialPresence {
  if (presence.state === 'offline') return presence
  const elapsed = Math.max(0, now.getTime() - Date.parse(presence.updatedAt))
  return {
    ...presence,
    todayFocusMs: presence.todayFocusMs + (presence.state === 'focusing' ? elapsed : 0),
    updatedAt: toISODateTime(now),
  }
}

/** Kalp atışı + (r'ye göre) durum geçişi. Girdi nesnesini değiştirmez. */
export function simulatePresence(presence: SocialPresence, r: number, now: Date): SocialPresence {
  const beat = heartbeat(presence, now)
  const next = nextPresenceState(presence.state, r)
  if (next === presence.state) return beat
  const nowIso = toISODateTime(now)
  if (next === 'offline') {
    return { ...beat, state: next, sessionStartedAt: null, stateSince: null, updatedAt: nowIso }
  }
  return {
    ...beat,
    state: next,
    stateSince: nowIso,
    sessionStartedAt: presence.state === 'offline' ? nowIso : beat.sessionStartedAt,
    updatedAt: nowIso,
  }
}
