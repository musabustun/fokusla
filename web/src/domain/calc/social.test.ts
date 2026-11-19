import { describe, expect, it } from 'vitest'
import type { FocusSegment, FocusSession, PresenceState, SocialPresence } from '../types'
import {
  INVITE_CODE_LENGTH,
  PRESENCE_STALE_AFTER_MS,
  USERNAME_MAX_LENGTH,
  USERNAME_MIN_LENGTH,
  effectivePresenceState,
  liveSessionMs,
  liveStateMs,
  liveTodayFocusMs,
  normalizeInviteCode,
  ownPresenceFromFocus,
  validateUsername,
  type UsernameValidation,
} from './social'

const SECOND = 1000
const MINUTE = 60 * SECOND

// Yerel saatle kurulur: testler saat diliminden bağımsızdır (yerel gece yarısı = 00:00).
const NOW = new Date(2026, 10, 19, 10, 0)
const at = (hour: number, minute = 0, day = 19) => new Date(2026, 10, day, hour, minute)
const iso = (date: Date) => date.toISOString()
const ago = (ms: number) => iso(new Date(NOW.getTime() - ms))

describe('constants', () => {
  it('exposes the documented limits', () => {
    expect(USERNAME_MIN_LENGTH).toBe(3)
    expect(USERNAME_MAX_LENGTH).toBe(20)
    expect(INVITE_CODE_LENGTH).toBe(6)
    expect(PRESENCE_STALE_AFTER_MS).toBe(10 * MINUTE)
  })
})

// ---------------------------------------------------------------------------
// validateUsername
// ---------------------------------------------------------------------------

describe('validateUsername', () => {
  const ok = (username: string): UsernameValidation => ({ ok: true, username })
  const problem = (p: Extract<UsernameValidation, { ok: false }>['problem']) =>
    ({ ok: false, problem: p }) as const

  it.each<[string, string, UsernameValidation]>([
    ['plain lowercase', 'musab', ok('musab')],
    ['leading @ dropped', '@musab', ok('musab')],
    ['surrounding whitespace trimmed', '  musab  ', ok('musab')],
    ['whitespace trimmed before @ is dropped', '  @musab ', ok('musab')],
    ['ASCII uppercase lowercased', 'MuSaB', ok('musab')],
    ['Turkish İ lowercased to i (tr-TR)', 'ALİ', ok('ali')],
    ['digits, dot and underscore allowed', 'ali.veli_42', ok('ali.veli_42')],
    ['exactly 3 characters', 'abc', ok('abc')],
    ['exactly 20 characters', 'a'.repeat(20), ok('a'.repeat(20))],
    ['@ does not count toward length', '@abc', ok('abc')],
    ['2 characters', 'ab', problem('tooShort')],
    ['empty', '', problem('tooShort')],
    ['only whitespace', '   ', problem('tooShort')],
    ['only @', '@', problem('tooShort')],
    ['@ + 2 characters', '@ab', problem('tooShort')],
    ['21 characters', 'a'.repeat(21), problem('tooLong')],
    ['ASCII I lowercased to dotless ı (tr-TR) → invalid', 'ALI', problem('invalidChars')],
    ['Turkish letters', 'şükrü', problem('invalidChars')],
    ['dotless ı', 'alı', problem('invalidChars')],
    ['inner space', 'ali veli', problem('invalidChars')],
    ['hyphen', 'ali-veli', problem('invalidChars')],
    ['only one leading @ dropped', '@@ali', problem('invalidChars')],
    ['@ in the middle', 'ali@veli', problem('invalidChars')],
    ['starts with digit', '1ali', problem('mustStartWithLetter')],
    ['starts with dot', '.ali', problem('mustStartWithLetter')],
    ['starts with underscore', '_ali', problem('mustStartWithLetter')],
    // Öncelik: uzunluk → karakter → ilk harf.
    ['too short wins over invalid chars', 'ş', problem('tooShort')],
    ['too short wins over first-letter', '1a', problem('tooShort')],
    ['too long wins over invalid chars', 'ş'.repeat(21), problem('tooLong')],
    ['invalid chars wins over first-letter', '1alı', problem('invalidChars')],
  ])('%s: %j', (_name, raw, expected) => {
    expect(validateUsername(raw)).toEqual(expected)
  })
})

// ---------------------------------------------------------------------------
// normalizeInviteCode
// ---------------------------------------------------------------------------

describe('normalizeInviteCode', () => {
  it.each<[string, string, string | null]>([
    ['already normalized', 'AB12CD', 'AB12CD'],
    ['lowercase is uppercased', 'ab12cd', 'AB12CD'],
    ['dash separated', 'AB1-2CD', 'AB12CD'],
    ['spaces anywhere', ' ab 12 cd ', 'AB12CD'],
    ['dashes and spaces mixed', 'a-b 1-2 c-d', 'AB12CD'],
    ['tab and newline removed', 'AB1\t2C\nD', 'AB12CD'],
    ['all digits', '123456', '123456'],
    // toUpperCase() (yerel ayarsız): dotless ı → I. Swift uppercased() da aynı davranır.
    ['dotless ı uppercases to I', 'abcdeı', 'ABCDEI'],
    ['5 characters', 'AB12C', null],
    ['7 characters', 'AB12CDE', null],
    ['empty', '', null],
    ['only separators', ' - - ', null],
    ['Turkish letter', 'AB12CŞ', null],
    ['dotted İ', 'AB12Cİ', null],
    ['punctuation', 'AB12C!', null],
    ['underscore', 'AB_2CD', null],
  ])('%s: %j → %j', (_name, raw, expected) => {
    expect(normalizeInviteCode(raw)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// Canlı durum
// ---------------------------------------------------------------------------

function presence(overrides: Partial<SocialPresence> = {}): SocialPresence {
  return {
    state: 'focusing',
    sessionStartedAt: ago(30 * MINUTE),
    stateSince: ago(5 * MINUTE),
    todayFocusMs: 60 * MINUTE,
    updatedAt: ago(MINUTE),
    ...overrides,
  }
}

const FRESH = ago(MINUTE)
const AT_THRESHOLD = ago(PRESENCE_STALE_AFTER_MS)
const JUST_STALE = ago(PRESENCE_STALE_AFTER_MS + 1)
const FUTURE = iso(new Date(NOW.getTime() + 2 * MINUTE))

describe('effectivePresenceState', () => {
  it.each<[string, SocialPresence | null, PresenceState]>([
    ['null presence', null, 'offline'],
    ['fresh focusing', presence({ state: 'focusing', updatedAt: FRESH }), 'focusing'],
    ['fresh onBreak', presence({ state: 'onBreak', updatedAt: FRESH }), 'onBreak'],
    ['fresh offline', presence({ state: 'offline', updatedAt: FRESH }), 'offline'],
    ['exactly at stale threshold', presence({ updatedAt: AT_THRESHOLD }), 'focusing'],
    ['1 ms past threshold', presence({ updatedAt: JUST_STALE }), 'offline'],
    ['stale onBreak', presence({ state: 'onBreak', updatedAt: JUST_STALE }), 'offline'],
    ['updatedAt in the future (clock skew)', presence({ updatedAt: FUTURE }), 'focusing'],
  ])('%s', (_name, input, expected) => {
    expect(effectivePresenceState(input, NOW)).toBe(expected)
  })
})

describe('liveTodayFocusMs', () => {
  const base = 60 * MINUTE

  it.each<[string, SocialPresence | null, number]>([
    ['null presence', null, 0],
    ['offline', presence({ state: 'offline', updatedAt: FRESH }), base],
    ['onBreak adds nothing', presence({ state: 'onBreak', updatedAt: FRESH }), base],
    ['focusing adds now − updatedAt', presence({ updatedAt: FRESH }), base + MINUTE],
    [
      'focusing exactly at threshold still adds',
      presence({ updatedAt: AT_THRESHOLD }),
      base + PRESENCE_STALE_AFTER_MS,
    ],
    ['stale focusing adds nothing', presence({ updatedAt: JUST_STALE }), base],
    ['negative clock skew adds 0', presence({ updatedAt: FUTURE }), base],
    ['zero base while focusing', presence({ todayFocusMs: 0, updatedAt: FRESH }), MINUTE],
  ])('%s', (_name, input, expected) => {
    expect(liveTodayFocusMs(input, NOW)).toBe(expected)
  })
})

describe('liveSessionMs', () => {
  it.each<[string, SocialPresence | null, number]>([
    ['null presence', null, 0],
    ['offline', presence({ state: 'offline', updatedAt: FRESH }), 0],
    ['stale', presence({ updatedAt: JUST_STALE }), 0],
    ['focusing', presence({ sessionStartedAt: ago(30 * MINUTE) }), 30 * MINUTE],
    ['onBreak', presence({ state: 'onBreak', sessionStartedAt: ago(45 * MINUTE) }), 45 * MINUTE],
    ['sessionStartedAt null', presence({ sessionStartedAt: null }), 0],
    ['negative clock skew → 0', presence({ sessionStartedAt: FUTURE }), 0],
  ])('%s', (_name, input, expected) => {
    expect(liveSessionMs(input, NOW)).toBe(expected)
  })
})

describe('liveStateMs', () => {
  it.each<[string, SocialPresence | null, number]>([
    ['null presence', null, 0],
    ['offline', presence({ state: 'offline', updatedAt: FRESH }), 0],
    ['stale', presence({ updatedAt: JUST_STALE }), 0],
    ['focusing', presence({ stateSince: ago(5 * MINUTE) }), 5 * MINUTE],
    ['onBreak', presence({ state: 'onBreak', stateSince: ago(2 * MINUTE) }), 2 * MINUTE],
    ['stateSince null', presence({ stateSince: null }), 0],
    ['negative clock skew → 0', presence({ stateSince: FUTURE }), 0],
  ])('%s', (_name, input, expected) => {
    expect(liveStateMs(input, NOW)).toBe(expected)
  })
})

// ---------------------------------------------------------------------------
// ownPresenceFromFocus
// ---------------------------------------------------------------------------

const CREATED = iso(at(0, 0, 1))

function session(id: string, startedAt: Date, endedAt: Date | null = null): FocusSession {
  return {
    id,
    createdAt: CREATED,
    updatedAt: CREATED,
    deletedAt: null,
    subjectId: null,
    topicId: null,
    startedAt: iso(startedAt),
    endedAt: endedAt ? iso(endedAt) : null,
    note: null,
  }
}

function segment(
  id: string,
  sessionId: string,
  kind: FocusSegment['kind'],
  startedAt: Date,
  endedAt: Date | null,
  extra: Partial<FocusSegment> = {},
): FocusSegment {
  return {
    id,
    createdAt: CREATED,
    updatedAt: CREATED,
    deletedAt: null,
    sessionId,
    kind,
    startedAt: iso(startedAt),
    endedAt: endedAt ? iso(endedAt) : null,
    ...extra,
  }
}

const ACTIVE = session('s-active', at(9, 0))
const DONE = session('s-done', at(7, 0), at(8, 0))

interface OwnCase {
  name: string
  activeSession: FocusSession | undefined
  segments: FocusSegment[]
  expected: Omit<SocialPresence, 'updatedAt'>
}

const ownCases: OwnCase[] = [
  {
    name: 'no active session, no segments → offline, 0',
    activeSession: undefined,
    segments: [],
    expected: { state: 'offline', sessionStartedAt: null, stateSince: null, todayFocusMs: 0 },
  },
  {
    name: 'no active session still reports today total from finished sessions',
    activeSession: undefined,
    segments: [
      segment('a', DONE.id, 'focus', at(7, 0), at(7, 25)),
      segment('b', DONE.id, 'break', at(7, 25), at(7, 30)),
      segment('c', DONE.id, 'focus', at(7, 30), at(8, 0)),
    ],
    expected: {
      state: 'offline',
      sessionStartedAt: null,
      stateSince: null,
      todayFocusMs: 55 * MINUTE,
    },
  },
  {
    name: 'open focus segment → focusing since its start; closed at now',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 20)),
      segment('b', ACTIVE.id, 'break', at(9, 20), at(9, 30)),
      segment('c', ACTIVE.id, 'focus', at(9, 30), null),
    ],
    expected: {
      state: 'focusing',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 30)),
      todayFocusMs: 50 * MINUTE,
    },
  },
  {
    name: 'open break segment → onBreak since its start',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 40)),
      segment('b', ACTIVE.id, 'break', at(9, 40), null),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 40)),
      todayFocusMs: 40 * MINUTE,
    },
  },
  {
    name: 'paused (no open segment) → onBreak since last segment end',
    activeSession: ACTIVE,
    segments: [
      segment('b', ACTIVE.id, 'focus', at(9, 30), at(9, 45)),
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 20)),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 45)),
      todayFocusMs: 35 * MINUTE,
    },
  },
  {
    name: 'active session without segments → onBreak since session start',
    activeSession: ACTIVE,
    segments: [segment('x', DONE.id, 'focus', at(7, 0), at(7, 10))],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 0)),
      todayFocusMs: 10 * MINUTE,
    },
  },
  {
    name: 'segment crossing local midnight is clipped to today',
    activeSession: session('s-night', at(23, 0, 18)),
    segments: [segment('n', 's-night', 'focus', at(23, 0, 18), null)],
    expected: {
      state: 'focusing',
      sessionStartedAt: iso(at(23, 0, 18)),
      stateSince: iso(at(23, 0, 18)),
      todayFocusMs: 10 * 60 * MINUTE,
    },
  },
  {
    name: 'closed segment entirely on the previous day counts 0',
    activeSession: undefined,
    segments: [
      segment('y', 's-old', 'focus', at(22, 0, 18), at(23, 0, 18)),
      segment('z', 's-old', 'focus', at(23, 30, 18), at(0, 15)),
    ],
    expected: {
      state: 'offline',
      sessionStartedAt: null,
      stateSince: null,
      todayFocusMs: 15 * MINUTE,
    },
  },
  {
    name: 'break segments never count toward today total',
    activeSession: undefined,
    segments: [segment('b', DONE.id, 'break', at(7, 0), at(8, 0))],
    expected: { state: 'offline', sessionStartedAt: null, stateSince: null, todayFocusMs: 0 },
  },
  {
    name: 'deleted segments are ignored (also for state)',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 20)),
      segment('b', ACTIVE.id, 'focus', at(9, 20), null, { deletedAt: iso(at(9, 25)) }),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 20)),
      todayFocusMs: 20 * MINUTE,
    },
  },
  {
    name: 'duplicate segment ids are counted once',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 30)),
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 30)),
      segment('b', ACTIVE.id, 'focus', at(9, 40), null),
      segment('b', ACTIVE.id, 'focus', at(9, 40), null),
    ],
    expected: {
      state: 'focusing',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 40)),
      todayFocusMs: 50 * MINUTE,
    },
  },
  {
    name: 'duplicate ids: the most recently updated copy wins',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), at(9, 30), { updatedAt: iso(at(9, 30)) }),
      segment('a', ACTIVE.id, 'focus', at(9, 0), null, { updatedAt: iso(at(9, 0)) }),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 30)),
      todayFocusMs: 30 * MINUTE,
    },
  },
  {
    name: 'several open segments (inconsistent data): the latest started decides the state',
    activeSession: ACTIVE,
    segments: [
      segment('a', ACTIVE.id, 'focus', at(9, 0), null),
      segment('b', ACTIVE.id, 'break', at(9, 50), null),
      segment('c', ACTIVE.id, 'focus', at(9, 10), null),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 50)),
      // Her açık odak segmenti now ile kapatılır: 60 + 50 dk.
      todayFocusMs: 110 * MINUTE,
    },
  },
  {
    name: 'segments of other sessions do not decide the state',
    activeSession: ACTIVE,
    segments: [
      segment('o', DONE.id, 'focus', at(7, 0), null),
      segment('a', ACTIVE.id, 'break', at(9, 50), null),
    ],
    expected: {
      state: 'onBreak',
      sessionStartedAt: iso(at(9, 0)),
      stateSince: iso(at(9, 50)),
      // Diğer oturumun açık segmenti de now ile kapatılmış sayılır: 07:00 → 10:00.
      todayFocusMs: 3 * 60 * MINUTE,
    },
  },
  {
    name: 'segment end after now (clock skew) is clipped to now',
    activeSession: undefined,
    segments: [segment('f', DONE.id, 'focus', at(9, 30), at(10, 30))],
    expected: {
      state: 'offline',
      sessionStartedAt: null,
      stateSince: null,
      todayFocusMs: 30 * MINUTE,
    },
  },
]

describe('ownPresenceFromFocus', () => {
  it.each(ownCases)('$name', ({ activeSession, segments, expected }) => {
    expect(ownPresenceFromFocus({ activeSession, segments }, NOW)).toEqual({
      ...expected,
      updatedAt: NOW.toISOString(),
    })
  })

  it('does not mutate its input', () => {
    const segments = Object.freeze([
      Object.freeze(segment('a', ACTIVE.id, 'focus', at(9, 0), null)),
    ])
    expect(() => ownPresenceFromFocus({ activeSession: ACTIVE, segments }, NOW)).not.toThrow()
  })
})
