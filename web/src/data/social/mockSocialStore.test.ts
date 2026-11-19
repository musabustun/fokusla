import { beforeEach, describe, expect, it } from 'vitest'
import type { KeyValueStorage } from '../storage'
import {
  parsePresence,
  parseStoredDocument,
  readAccount,
  SOCIAL_MOCK_STORAGE_KEY,
  writeAccount,
  type StoredAccount,
} from './mockSocialStore'

const AT = '2026-11-19T07:00:00.000Z'

const account = (username: string): StoredAccount => ({
  profile: { userId: `self-${username}`, username, inviteCode: 'ABC234', isDiscoverable: true },
  friends: [{ userId: 'u1', username: 'elif.say', friendsSince: AT }],
  requests: [
    {
      id: 'r1',
      direction: 'incoming',
      user: { userId: 'u2', username: 'zeynep2027' },
      createdAt: AT,
    },
  ],
  room: {
    kind: 'hosted',
    id: 'room1',
    name: 'Gece',
    inviteCode: 'GECE23',
    createdAt: AT,
    guests: [{ userId: 'u1', joinedAt: AT }],
  },
  selfPresence: {
    state: 'focusing',
    sessionStartedAt: AT,
    stateSince: AT,
    todayFocusMs: 1000,
    updatedAt: AT,
  },
})

const doc = (accounts: Record<string, unknown>) => JSON.stringify({ version: 1, accounts })

describe('mockSocialStore', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('round-trips accounts and keeps other users intact', () => {
    writeAccount(localStorage, 'apple-a', account('ali'))
    writeAccount(localStorage, 'apple-b', account('veli'))

    expect(readAccount(localStorage, 'apple-a')).toEqual(account('ali'))
    expect(readAccount(localStorage, 'apple-b')).toEqual(account('veli'))
    expect(readAccount(localStorage, 'apple-c')).toBeNull()
    expect(readAccount(localStorage, 'toString')).toBeNull()
  })

  it.each([
    null,
    '{bozuk',
    '[]',
    '"x"',
    '{"version":2,"accounts":{}}',
    '{"version":1,"accounts":[]}',
  ])('parses %s as an empty document', (raw) => {
    expect(parseStoredDocument(raw)).toEqual({ version: 1, accounts: {} })
  })

  it('drops accounts with an invalid profile', () => {
    const parsed = parseStoredDocument(
      doc({
        good: account('ali'),
        noProfile: { friends: [] },
        badProfile: {
          profile: { userId: 'x', username: 'y', inviteCode: '', isDiscoverable: true },
        },
        notObject: 42,
      }),
    )
    expect(Object.keys(parsed.accounts)).toEqual(['good'])
  })

  it('filters invalid list entries and resets invalid room/presence', () => {
    const raw = {
      ...account('ali'),
      friends: [{ userId: 'u1', username: 'a', friendsSince: AT }, { userId: 'u2' }, 'x'],
      requests: [
        { id: 'r1', direction: 'sideways', user: { userId: 'u', username: 'n' }, createdAt: AT },
        { id: 'r2', direction: 'outgoing', user: null, createdAt: AT },
        { id: 'r3', direction: 'outgoing', user: { userId: 'u', username: 'n' }, createdAt: AT },
        null,
      ],
      room: { kind: 'other' },
      selfPresence: { state: 'sleeping' },
    }

    const parsed = parseStoredDocument(doc({ a: raw })).accounts.a

    expect(parsed?.friends).toEqual([{ userId: 'u1', username: 'a', friendsSince: AT }])
    expect(parsed?.requests.map((r) => r.id)).toEqual(['r3'])
    expect(parsed?.room).toBeNull()
    expect(parsed?.selfPresence).toBeNull()
  })

  it('parses joined rooms and validates their fields', () => {
    const joined = { kind: 'joined', roomId: 'mock-room-sabah', joinedAt: AT }
    const parse = (room: unknown) =>
      parseStoredDocument(doc({ a: { ...account('ali'), room } })).accounts.a?.room

    expect(parse(joined)).toEqual(joined)
    expect(parse({ ...joined, roomId: '' })).toBeNull()
    expect(parse({ kind: 'hosted', id: 'r', name: '', inviteCode: 'X', createdAt: AT })).toBeNull()
    expect(parse({ kind: 'hosted', id: 'r', name: 'n', inviteCode: '', createdAt: AT })).toBeNull()
    expect(
      parse({ kind: 'hosted', id: 'r', name: 'n', inviteCode: 'X', createdAt: AT, guests: 'x' }),
    ).toMatchObject({ guests: [] })
    expect(
      parse({
        kind: 'hosted',
        id: 'r',
        name: 'n',
        inviteCode: 'X',
        createdAt: AT,
        guests: [{ userId: 'u' }, null, { userId: 'u', joinedAt: AT }],
      }),
    ).toMatchObject({ guests: [{ userId: 'u', joinedAt: AT }] })
    expect(parse('room')).toBeNull()
  })

  it.each([
    [{ state: 'focusing', sessionStartedAt: 1, stateSince: null, todayFocusMs: 0, updatedAt: AT }],
    [
      {
        state: 'focusing',
        sessionStartedAt: null,
        stateSince: null,
        todayFocusMs: -1,
        updatedAt: AT,
      },
    ],
    [
      {
        state: 'focusing',
        sessionStartedAt: null,
        stateSince: null,
        todayFocusMs: NaN,
        updatedAt: AT,
      },
    ],
    [
      {
        state: 'focusing',
        sessionStartedAt: null,
        stateSince: null,
        todayFocusMs: 0,
        updatedAt: '',
      },
    ],
    [[]],
  ])('rejects invalid presence %o', (value) => {
    expect(parsePresence(value)).toBeNull()
  })

  it('never throws when storage is unavailable', () => {
    const broken: KeyValueStorage = {
      getItem: () => {
        throw new Error('kapalı')
      },
      setItem: () => {
        throw new Error('kota')
      },
      removeItem: () => undefined,
    }
    expect(() => writeAccount(broken, 'a', account('ali'))).not.toThrow()
    expect(readAccount(broken, 'a')).toBeNull()
    expect(readAccount(null, 'a')).toBeNull()
    expect(localStorage.getItem(SOCIAL_MOCK_STORAGE_KEY)).toBeNull()
  })
})
