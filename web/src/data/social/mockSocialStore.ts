/**
 * MockSocialService'in localStorage kalıcılığı. Saklanan JSON savunmacı biçimde ayrıştırılır:
 * bozuk ya da yabancı veri boş kabul edilir, ASLA fırlatılmaz. Geçersiz alt kayıtlar atlanır.
 *
 * Simüle kullanıcıların canlı durumları burada SAKLANMAZ.
 */
import type { ISODateTime, PresenceState, SocialPresence } from '@/domain'
import { safeGetItem, safeSetItem, type KeyValueStorage } from '../storage'
import type { FriendRequest, SocialProfile, SocialUser } from './SocialService'

export const SOCIAL_MOCK_STORAGE_KEY = 'fokus.social.mock.v1'
const STORAGE_VERSION = 1

export interface StoredFriend extends SocialUser {
  friendsSince: ISODateTime
}

export interface StoredRoomGuest {
  userId: string
  joinedAt: ISODateTime
}

/** Ya simüle bir odaya katıldım ya da kendi odamı açtım. */
export type StoredRoom =
  | { kind: 'joined'; roomId: string; joinedAt: ISODateTime }
  | {
      kind: 'hosted'
      id: string
      name: string
      inviteCode: string
      createdAt: ISODateTime
      guests: readonly StoredRoomGuest[]
    }

export interface StoredAccount {
  profile: SocialProfile
  friends: readonly StoredFriend[]
  requests: readonly FriendRequest[]
  room: StoredRoom | null
  /** Son yayınlanan kendi durumum (görünmezsem null). */
  selfPresence: SocialPresence | null
}

export interface StoredDocument {
  version: typeof STORAGE_VERSION
  /** Anahtar: Apple kullanıcı kimliği. */
  accounts: Readonly<Record<string, StoredAccount>>
}

type UnknownRecord = Record<string, unknown>

const EMPTY_DOCUMENT: StoredDocument = { version: STORAGE_VERSION, accounts: {} }
const PRESENCE_STATES: readonly PresenceState[] = ['focusing', 'onBreak', 'offline']

const isRecord = (value: unknown): value is UnknownRecord =>
  typeof value === 'object' && value !== null && !Array.isArray(value)
const isString = (value: unknown): value is string => typeof value === 'string'
const isNonEmptyString = (value: unknown): value is string => isString(value) && value.length > 0
const isNullableString = (value: unknown): value is string | null =>
  value === null || isString(value)

/** Dizinin geçerli öğelerini ayrıştırır; dizi değilse boş liste. */
function parseList<T>(value: unknown, parseItem: (item: unknown) => T | null): T[] {
  if (!Array.isArray(value)) return []
  return value.map(parseItem).filter((item): item is T => item !== null)
}

function parseUser(value: unknown): SocialUser | null {
  if (!isRecord(value)) return null
  const { userId, username } = value
  if (!isNonEmptyString(userId) || !isNonEmptyString(username)) return null
  return { userId, username }
}

function parseProfile(value: unknown): SocialProfile | null {
  const user = parseUser(value)
  if (!user || !isRecord(value)) return null
  const { inviteCode, isDiscoverable } = value
  if (!isNonEmptyString(inviteCode) || typeof isDiscoverable !== 'boolean') return null
  return { ...user, inviteCode, isDiscoverable }
}

function parseFriend(value: unknown): StoredFriend | null {
  const user = parseUser(value)
  if (!user || !isRecord(value) || !isNonEmptyString(value.friendsSince)) return null
  return { ...user, friendsSince: value.friendsSince }
}

function parseRequest(value: unknown): FriendRequest | null {
  if (!isRecord(value)) return null
  const { id, direction, createdAt } = value
  const user = parseUser(value.user)
  if (!isNonEmptyString(id) || !isNonEmptyString(createdAt) || !user) return null
  if (direction !== 'incoming' && direction !== 'outgoing') return null
  return { id, direction, user, createdAt }
}

function parseGuest(value: unknown): StoredRoomGuest | null {
  if (!isRecord(value)) return null
  const { userId, joinedAt } = value
  if (!isNonEmptyString(userId) || !isNonEmptyString(joinedAt)) return null
  return { userId, joinedAt }
}

function parseRoom(value: unknown): StoredRoom | null {
  if (!isRecord(value)) return null
  if (value.kind === 'joined') {
    const { roomId, joinedAt } = value
    if (!isNonEmptyString(roomId) || !isNonEmptyString(joinedAt)) return null
    return { kind: 'joined', roomId, joinedAt }
  }
  if (value.kind !== 'hosted') return null
  const { id, name, inviteCode, createdAt } = value
  if (!isNonEmptyString(id) || !isNonEmptyString(name)) return null
  if (!isNonEmptyString(inviteCode) || !isNonEmptyString(createdAt)) return null
  return {
    kind: 'hosted',
    id,
    name,
    inviteCode,
    createdAt,
    guests: parseList(value.guests, parseGuest),
  }
}

export function parsePresence(value: unknown): SocialPresence | null {
  if (!isRecord(value)) return null
  const { state, sessionStartedAt, stateSince, todayFocusMs, updatedAt } = value
  if (!PRESENCE_STATES.includes(state as PresenceState)) return null
  if (!isNullableString(sessionStartedAt) || !isNullableString(stateSince)) return null
  if (typeof todayFocusMs !== 'number' || !Number.isFinite(todayFocusMs) || todayFocusMs < 0) {
    return null
  }
  if (!isNonEmptyString(updatedAt)) return null
  return {
    state: state as PresenceState,
    sessionStartedAt,
    stateSince,
    todayFocusMs,
    updatedAt,
  }
}

function parseAccount(value: unknown): StoredAccount | null {
  if (!isRecord(value)) return null
  const profile = parseProfile(value.profile)
  if (!profile) return null
  return {
    profile,
    friends: parseList(value.friends, parseFriend),
    requests: parseList(value.requests, parseRequest),
    room: parseRoom(value.room),
    selfPresence: parsePresence(value.selfPresence),
  }
}

/** Saklanan belgeyi ayrıştırır; bozuk/yabancı veri için boş belge döner, asla fırlatmaz. */
export function parseStoredDocument(raw: string | null): StoredDocument {
  if (raw === null) return EMPTY_DOCUMENT
  let data: unknown
  try {
    data = JSON.parse(raw)
  } catch {
    return EMPTY_DOCUMENT
  }
  if (!isRecord(data) || data.version !== STORAGE_VERSION || !isRecord(data.accounts)) {
    return EMPTY_DOCUMENT
  }
  const accounts = Object.entries(data.accounts)
    .map(([appleUserId, account]) => [appleUserId, parseAccount(account)] as const)
    .filter((entry): entry is readonly [string, StoredAccount] => entry[1] !== null)
  return { version: STORAGE_VERSION, accounts: Object.fromEntries(accounts) }
}

export function readAccount(
  storage: KeyValueStorage | null,
  appleUserId: string,
): StoredAccount | null {
  const document = parseStoredDocument(safeGetItem(storage, SOCIAL_MOCK_STORAGE_KEY))
  if (!Object.hasOwn(document.accounts, appleUserId)) return null
  return document.accounts[appleUserId] ?? null
}

/** Hesabı belgeye yazar; diğer hesaplar korunur. */
export function writeAccount(
  storage: KeyValueStorage | null,
  appleUserId: string,
  account: StoredAccount,
): void {
  const current = parseStoredDocument(safeGetItem(storage, SOCIAL_MOCK_STORAGE_KEY))
  const next: StoredDocument = {
    version: STORAGE_VERSION,
    accounts: { ...current.accounts, [appleUserId]: account },
  }
  safeSetItem(storage, SOCIAL_MOCK_STORAGE_KEY, JSON.stringify(next))
}
