/**
 * Sosyal hesapları — SAF fonksiyonlar (React/Dexie yok). Sahibi: social feature oturumu.
 * Tüm canlı süreler `now` parametresiyle hesaplanır. Birim: milisaniye.
 */
import type {
  FocusSegment,
  FocusSession,
  ISODateTime,
  PresenceState,
  SocialPresence,
} from '../types'
import { toISODateTime } from '../ids'

// ---------------------------------------------------------------------------
// Kullanıcı adı ve davet kodu
// ---------------------------------------------------------------------------

export const USERNAME_MIN_LENGTH = 3
export const USERNAME_MAX_LENGTH = 20

/** Kullanıcı adı neden geçersiz? (`taken` tekillik kontrolüdür, SocialService döner.) */
export type UsernameProblem = 'tooShort' | 'tooLong' | 'invalidChars' | 'mustStartWithLetter'

const USERNAME_CHARS = /^[a-z0-9._]+$/
const USERNAME_FIRST_LETTER = /^[a-z]/

export type UsernameValidation =
  { ok: true; username: string } | { ok: false; problem: UsernameProblem }

/**
 * Kullanıcı adını normalleştirir ve doğrular.
 * Normalleştirme: baş/son boşluk kırpılır, baştaki tek `@` atılır, `toLocaleLowerCase('tr-TR')`.
 * Kurallar: 3–20 karakter; yalnızca a–z, 0–9, `.` ve `_` (ASCII — Türkçe harf yok, `ı`/`İ` dahil);
 * ilk karakter harf. Sıra: uzunluk (tooShort/tooLong) → karakter (invalidChars) → ilk harf.
 */
export function validateUsername(raw: string): UsernameValidation {
  const trimmed = raw.trim()
  const withoutAt = trimmed.startsWith('@') ? trimmed.slice(1) : trimmed
  const username = withoutAt.toLocaleLowerCase('tr-TR')
  const length = Array.from(username).length
  if (length < USERNAME_MIN_LENGTH) return { ok: false, problem: 'tooShort' }
  if (length > USERNAME_MAX_LENGTH) return { ok: false, problem: 'tooLong' }
  if (!USERNAME_CHARS.test(username)) return { ok: false, problem: 'invalidChars' }
  if (!USERNAME_FIRST_LETTER.test(username)) return { ok: false, problem: 'mustStartWithLetter' }
  return { ok: true, username }
}

export const INVITE_CODE_LENGTH = 6
const INVITE_CODE_PATTERN = new RegExp(`^[A-Z0-9]{${INVITE_CODE_LENGTH}}$`)

/**
 * Davet kodunu normalleştirir: boşluk ve `-` atılır, `toUpperCase()`.
 * Geçerli kod tam 6 karakter A–Z/0–9'dur; değilse null döner.
 */
export function normalizeInviteCode(raw: string): string | null {
  const code = raw.replace(/[\s-]/g, '').toUpperCase()
  return INVITE_CODE_PATTERN.test(code) ? code : null
}

// ---------------------------------------------------------------------------
// Canlı durum
// ---------------------------------------------------------------------------

/**
 * Durum bu süreden daha eskiyse (yayınlayan cihaz kapanmış/çevrimdışı olabilir) çevrimdışı sayılır.
 * CloudKit gerçek zamanlı değildir; kalp atışı ~60 sn'de bir gelir (bkz. ARCHITECTURE 4.7).
 */
export const PRESENCE_STALE_AFTER_MS = 10 * 60 * 1000

/** `now − iso` (ms); negatif olabilir. */
function msSince(iso: ISODateTime, now: Date): number {
  return now.getTime() - Date.parse(iso)
}

/** Geçen süre (ms); başlangıç yoksa veya gelecekteyse (saat kayması) 0. */
function elapsedMs(since: ISODateTime | null, now: Date): number {
  return since === null ? 0 : Math.max(0, msSince(since, now))
}

/**
 * Gösterilecek durum: presence null → 'offline'; `now − updatedAt > PRESENCE_STALE_AFTER_MS`
 * → 'offline'; aksi halde presence.state.
 */
export function effectivePresenceState(presence: SocialPresence | null, now: Date): PresenceState {
  if (!presence) return 'offline'
  if (msSince(presence.updatedAt, now) > PRESENCE_STALE_AFTER_MS) return 'offline'
  return presence.state
}

/**
 * Canlı bugünkü toplam odak (ms): todayFocusMs + (etkin durum 'focusing' ise now − updatedAt).
 * Presence null → 0. Negatif fark (saat kayması) 0 sayılır. Bayatsa yalnızca todayFocusMs.
 */
export function liveTodayFocusMs(presence: SocialPresence | null, now: Date): number {
  if (!presence) return 0
  if (effectivePresenceState(presence, now) !== 'focusing') return presence.todayFocusMs
  return presence.todayFocusMs + elapsedMs(presence.updatedAt, now)
}

/** Sürmekte olan oturumun süresi (ms): now − sessionStartedAt; etkin durum offline ise 0. */
export function liveSessionMs(presence: SocialPresence | null, now: Date): number {
  if (effectivePresenceState(presence, now) === 'offline') return 0
  return elapsedMs(presence?.sessionStartedAt ?? null, now)
}

/** Mevcut durumun (odak/mola) süresi (ms): now − stateSince; etkin durum offline ise 0. */
export function liveStateMs(presence: SocialPresence | null, now: Date): number {
  if (effectivePresenceState(presence, now) === 'offline') return 0
  return elapsedMs(presence?.stateSince ?? null, now)
}

// ---------------------------------------------------------------------------
// Kendi durumum (focus verisinden YALNIZCA OKUNARAK)
// ---------------------------------------------------------------------------

export interface OwnFocusSnapshot {
  /** endedAt === null olan oturum (FocusSessionRepository.findActive). */
  activeSession: FocusSession | undefined
  /** Bugün başlayan oturumların + aktif oturumun segmentleri (tekrar içerebilir: id ile tekilleştir). */
  segments: readonly FocusSegment[]
}

/**
 * Focus modülünün kayıtlarından kendi paylaşılacak durumumu üretir (focus verisine YAZMAZ).
 *  - Aktif oturum yoksa: state 'offline', sessionStartedAt/stateSince null.
 *  - Aktif oturum varsa: aktif oturumun açık segmenti (endedAt null) 'focus' → 'focusing',
 *    'break' → 'onBreak'; açık segment yoksa 'onBreak' (duraklatılmış). stateSince = açık
 *    segmentin startedAt'i (yoksa aktif oturumun son segmentinin endedAt'i, o da yoksa oturum başı).
 *    sessionStartedAt = aktif oturumun startedAt'i.
 *  - todayFocusMs: 'focus' segmentlerinin `now`'ın YEREL gününe (00:00 → now) düşen kısmı;
 *    açık segment now ile kapatılmış sayılır; silinmiş (deletedAt != null) segmentler atlanır;
 *    aynı id'li segment bir kez sayılır.
 *  - updatedAt = now (ISO).
 */
export function ownPresenceFromFocus(snapshot: OwnFocusSnapshot, now: Date): SocialPresence {
  const segments = liveUniqueSegments(snapshot.segments)
  const todayFocusMs = focusMsOnLocalDay(segments, now)
  const updatedAt = toISODateTime(now)
  const { activeSession } = snapshot
  if (!activeSession) {
    return { state: 'offline', sessionStartedAt: null, stateSince: null, todayFocusMs, updatedAt }
  }
  const sessionSegments = segments.filter((segment) => segment.sessionId === activeSession.id)
  const { state, stateSince } = activeState(activeSession, sessionSegments)
  return { state, sessionStartedAt: activeSession.startedAt, stateSince, todayFocusMs, updatedAt }
}

/**
 * Silinmemiş, id'ye göre tekilleştirilmiş segmentler. Aynı id'nin birden çok kopyası varsa
 * `updatedAt`'i en yeni olan (eşitse ilk gelen) kazanır; silinme kontrolü kazanan kopyaya bakar.
 */
function liveUniqueSegments(segments: readonly FocusSegment[]): FocusSegment[] {
  const byId = new Map<string, FocusSegment>()
  for (const segment of segments) {
    const existing = byId.get(segment.id)
    if (!existing || segment.updatedAt > existing.updatedAt) byId.set(segment.id, segment)
  }
  return [...byId.values()].filter((segment) => segment.deletedAt === null)
}

/** 'focus' segmentlerinin `now`'ın yerel gününe (00:00 → now) düşen toplamı (ms). */
function focusMsOnLocalDay(segments: readonly FocusSegment[], now: Date): number {
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const nowMs = now.getTime()
  return segments
    .filter((segment) => segment.kind === 'focus')
    .reduce((total, segment) => {
      const start = Math.max(Date.parse(segment.startedAt), dayStart)
      const end = Math.min(segment.endedAt === null ? nowMs : Date.parse(segment.endedAt), nowMs)
      return total + Math.max(0, end - start)
    }, 0)
}

function latestBy(
  segments: readonly FocusSegment[],
  key: (segment: FocusSegment) => string,
): FocusSegment | undefined {
  return segments.reduce<FocusSegment | undefined>(
    (latest, segment) => (!latest || key(segment) > key(latest) ? segment : latest),
    undefined,
  )
}

function activeState(
  session: FocusSession,
  sessionSegments: readonly FocusSegment[],
): { state: PresenceState; stateSince: ISODateTime } {
  const open = latestBy(
    sessionSegments.filter((segment) => segment.endedAt === null),
    (segment) => segment.startedAt,
  )
  if (open) {
    return { state: open.kind === 'focus' ? 'focusing' : 'onBreak', stateSince: open.startedAt }
  }
  // Duraklatılmış: tüm segmentler kapalı → son bitişten beri mola.
  const lastEndedAt = sessionSegments
    .map((segment) => segment.endedAt)
    .filter((endedAt): endedAt is ISODateTime => endedAt !== null)
    .reduce<ISODateTime | null>(
      (latest, endedAt) => (latest && latest > endedAt ? latest : endedAt),
      null,
    )
  return { state: 'onBreak', stateSince: lastEndedAt ?? session.startedAt }
}
