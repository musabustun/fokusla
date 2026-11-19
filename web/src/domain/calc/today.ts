/**
 * Bugün ekranının hesapları — SAF fonksiyonlar (React/Dexie/Date.now yok). Sahibi: today oturumu.
 *
 * Kurallar:
 *  - Diğer modüllerin calc fonksiyonları YENİDEN KULLANILIR (focus, tasks, tests, books, social);
 *    burada yalnızca Bugün'e özgü birleştirme/seçim mantığı vardır.
 *  - "Şimdi" `now: Date`, takvim günü `today: ISODate` (YEREL) parametre olarak gelir.
 *  - Silinmiş kayıtlar (`deletedAt != null`) her fonksiyonda yok sayılır.
 *  - Girdiler mutasyona uğramaz.
 *  - Kullanıcıya görünen metin üretilmez; anahtarlar döner (UI Türkçeye çevirir, Swift de aynı).
 */
import type {
  FocusSegment,
  FocusSession,
  ISODate,
  SocialPresence,
  Task,
  TaskCompletion,
  TestResult,
  UUID,
} from '../types'
import { toISODate } from '../ids'
import type { BookSummary } from './books'
import {
  computeSessionStats,
  dailyFocusTotalMs,
  dailyFocusTotals,
  getFocusPhase,
  type DailyFocusTotal,
  type FocusPhase,
} from './focus'
import { effectivePresenceState } from './social'
import { addDays, agendaForDay, findCompletion, isCompletedOn } from './tasks'
import {
  findWeakestTopics,
  questionCount,
  summarizeByTopic,
  summarizeResults,
  type TestSummary,
  type WeakTopic,
} from './tests'

// ---------------------------------------------------------------------------
// Selam
// ---------------------------------------------------------------------------

export type GreetingKey = 'morning' | 'afternoon' | 'evening' | 'night'

/** Saat aralıkları (yerel, [başlangıç, bitiş)): sabah 05–12, öğleden sonra 12–18, akşam 18–22. */
const MORNING_START_HOUR = 5
const AFTERNOON_START_HOUR = 12
const EVENING_START_HOUR = 18
const NIGHT_START_HOUR = 22

/** `now`'ın YEREL saatine göre selam anahtarı. */
export function greetingKey(now: Date): GreetingKey {
  const hour = now.getHours()
  if (hour >= NIGHT_START_HOUR || hour < MORNING_START_HOUR) return 'night'
  if (hour >= EVENING_START_HOUR) return 'evening'
  if (hour >= AFTERNOON_START_HOUR) return 'afternoon'
  return 'morning'
}

// ---------------------------------------------------------------------------
// Odak
// ---------------------------------------------------------------------------

/** Bugün kartındaki mini grafikte gösterilen gün sayısı (bugün dahil). */
export const TODAY_CHART_DAYS = 7

export interface TodayFocusSummary {
  /** Bugün (yerel gün) toplam odak (ms); gece yarısını aşan segmentler bölünür, açık segment `now`'a kadar. */
  totalMs: number
  /** Bugün odak süresi olan (ya da bugün başlayan ya da hâlâ açık) silinmemiş oturum sayısı. */
  sessionCount: number
  /** Bu oturumların KAPANMIŞ odak segmentlerinin ortalaması (ms); yoksa 0. */
  averageFocusMs: number
}

function isLive(entity: { deletedAt: string | null }): boolean {
  return entity.deletedAt === null
}

/** Oturum bugüne dokunuyor mu: bugün başladı, hâlâ açık ya da bugün odak süresi var. */
function touchesDay(
  session: FocusSession,
  segments: readonly FocusSegment[],
  today: ISODate,
  now: Date,
): boolean {
  if (session.endedAt === null) return true
  if (toISODate(new Date(session.startedAt)) === today) return true
  const own = segments.filter((s) => s.sessionId === session.id)
  return dailyFocusTotalMs([session], own, today, now) > 0
}

/**
 * Bugünün odak özeti. `sessions`/`segments` en az bugüne dokunan oturumları içermelidir
 * (fazlası zarar vermez). Ortalama, bugüne dokunan oturumların tüm kapanmış odak segmentlerinden.
 */
export function todayFocusSummary(
  sessions: readonly FocusSession[],
  segments: readonly FocusSegment[],
  today: ISODate,
  now: Date,
): TodayFocusSummary {
  const todaySessions = sessions.filter(
    (session) => isLive(session) && touchesDay(session, segments, today, now),
  )
  const ids = new Set(todaySessions.map((session) => session.id))
  const todaySegments = segments.filter((segment) => ids.has(segment.sessionId))
  return {
    totalMs: dailyFocusTotalMs(sessions, segments, today, now),
    sessionCount: todaySessions.length,
    averageFocusMs: computeSessionStats(todaySegments, now).averageFocusMs,
  }
}

export interface ActiveFocusState {
  /** Açık oturumun anlık durumu ('ended' oluşmaz: o durumda fonksiyon null döner). */
  phase: Exclude<FocusPhase, 'ended'>
  /** Oturumun toplam odak süresi (ms), açık odak segmenti `now`'a kadar. */
  sessionFocusMs: number
}

/**
 * Açık oturumun canlı durumu. Oturum yoksa, bitmiş ya da silinmişse null.
 * `segments` başka oturumlara ait segmentler de içerebilir; yalnızca bu oturumunkiler sayılır.
 */
export function activeFocusState(
  session: FocusSession | undefined,
  segments: readonly FocusSegment[],
  now: Date,
): ActiveFocusState | null {
  if (session === undefined) return null
  const phase = getFocusPhase(session, segments)
  if (phase === 'ended') return null
  const own = segments.filter((segment) => segment.sessionId === session.id)
  return { phase, sessionFocusMs: computeSessionStats(own, now).focusMs }
}

/** Son `days` günün (bugün dahil, eskiden yeniye) günlük odak toplamları. days ≤ 0 → []. */
export function recentFocusTotals(
  sessions: readonly FocusSession[],
  segments: readonly FocusSegment[],
  today: ISODate,
  now: Date,
  days: number = TODAY_CHART_DAYS,
): DailyFocusTotal[] {
  const count = Math.max(0, Math.floor(days))
  const list = Array.from({ length: count }, (_, i) => addDays(today, i - count + 1))
  return dailyFocusTotals(sessions, segments, list, now)
}

/** Odak halkasının canlı oturumdaki tur uzunluğu (ms): 1 saat. */
export const FOCUS_RING_LAP_MS = 3_600_000

/** Halkanın neyi gösterdiği: canlı oturumun saatlik turu ya da bugünün son 7 günün en iyisine oranı. */
export type FocusRingKind = 'sessionLap' | 'weekBest'

export interface FocusRingProgress {
  kind: FocusRingKind
  /** 0–1. */
  value: number
}

/**
 * Bugün odak halkası. Açık oturum varsa (`activeSessionMs` ≥ 0): oturum süresinin saatlik turu
 * (dakika / 60; tam saatte tur başa sarar). Yoksa `todayMs` / `totals` içindeki en iyi gün
 * (bugün dahil; en iyi 0 ise 0). Değer her zaman 0–1 arasıdır.
 */
export function focusRingProgress(
  todayMs: number,
  totals: readonly DailyFocusTotal[],
  activeSessionMs: number | null,
): FocusRingProgress {
  if (activeSessionMs !== null) {
    const lap = Math.max(0, activeSessionMs) % FOCUS_RING_LAP_MS
    return { kind: 'sessionLap', value: lap / FOCUS_RING_LAP_MS }
  }
  const today = Math.max(0, todayMs)
  const best = Math.max(today, ...totals.map((total) => total.focusMs))
  return { kind: 'weekBest', value: best > 0 ? today / best : 0 }
}

// ---------------------------------------------------------------------------
// Görevler
// ---------------------------------------------------------------------------

/** Görevin Bugün kartındaki grubu (görüntü sırası budur). */
export type TodayTaskGroup = 'overdue' | 'routine' | 'dueToday' | 'upcoming'

export interface TodayTaskItem {
  task: Task
  group: TodayTaskGroup
  /** `today` itibarıyla tamamlanmış mı (tasks calc `isCompletedOn`). */
  done: boolean
}

export interface TodayTaskOverview {
  /** Sıra: gecikenler, rutinler, bugün teslim/tarihsiz, yaklaşanlar. */
  items: TodayTaskItem[]
  /** Bugün yapılacaklar (gecikmiş + rutin + bugün teslim/tarihsiz) sayısı. Yaklaşanlar hariç. */
  totalCount: number
  /** Bunlardan tamamlananlar. */
  doneCount: number
}

const COUNTED_GROUPS: ReadonlySet<TodayTaskGroup> = new Set(['overdue', 'routine', 'dueToday'])

/** Bugünün görev özeti (tasks calc `agendaForDay` üzerine). */
export function todayTaskOverview(
  tasks: readonly Task[],
  completions: readonly TaskCompletion[],
  today: ISODate,
): TodayTaskOverview {
  const agenda = agendaForDay(tasks, today)
  const grouped: [TodayTaskGroup, Task[]][] = [
    ['overdue', agenda.overdue],
    ['routine', agenda.routines],
    ['dueToday', agenda.dueToday],
    ['upcoming', agenda.upcoming],
  ]
  const items = grouped.flatMap(([group, list]) =>
    list.map((task): TodayTaskItem => ({
      task,
      group,
      done: isCompletedOn(task, completions, today),
    })),
  )
  const counted = items.filter((item) => COUNTED_GROUPS.has(item.group))
  return {
    items,
    totalCount: counted.length,
    doneCount: counted.filter((item) => item.done).length,
  }
}

/**
 * Tamamla/geri al için yapılacak yazma. Feature bunu repository ile uygular:
 *  - createCompletion: `taskCompletions.create({ taskId, date, completedAt: now, quantity: null })`
 *  - deleteCompletions: listelenen her tamamlamayı soft-delete et (geri al)
 *  - setAssignmentCompleted: `tasks.update(id, { completedAt: completed ? now : null,
 *    completedQuantity: null })`
 *  - none: silinmiş görev (yazma yok)
 */
export type TaskToggleAction =
  | { kind: 'createCompletion'; taskId: UUID; date: ISODate }
  | { kind: 'deleteCompletions'; completionIds: UUID[] }
  | { kind: 'setAssignmentCompleted'; taskId: UUID; completed: boolean }
  | { kind: 'none' }

/**
 * Görevler modülündeki tek dokunuşla tamamla/geri al davranışının aynısı (bkz. tasks
 * `toggleCompletion`): rutinde o güne ait TÜM silinmemiş tamamlamalar geri alınır.
 */
export function planTaskToggle(
  task: Task,
  completions: readonly TaskCompletion[],
  day: ISODate,
): TaskToggleAction {
  if (!isLive(task)) return { kind: 'none' }
  if (task.kind === 'assignment') {
    return { kind: 'setAssignmentCompleted', taskId: task.id, completed: task.completedAt === null }
  }
  if (findCompletion(completions, task.id, day) === undefined) {
    return { kind: 'createCompletion', taskId: task.id, date: day }
  }
  const completionIds = completions
    .filter((c) => c.taskId === task.id && c.date === day && isLive(c))
    .map((c) => c.id)
  return { kind: 'deleteCompletions', completionIds }
}

// ---------------------------------------------------------------------------
// Testler
// ---------------------------------------------------------------------------

/** "Son testler" penceresi: son 7 gün (bugün dahil). */
export const RECENT_TESTS_WINDOW_DAYS = 7
/** Bugün kartında gösterilen en zayıf konu sayısı. */
export const TODAY_WEAK_TOPIC_LIMIT = 3

export interface RecentTestsSummary {
  /** Bugün (yerel gün) çözülen soru sayısı. */
  todayQuestions: number
  /** Son `windowDays` günün özeti (tests calc `summarizeResults`). */
  window: TestSummary
  /** Silinmemiş tüm test sonuçlarının sayısı (boş durum için). */
  allTimeCount: number
}

/** Bugün ve son `windowDays` gün (bugün dahil; en az 1) çözülen testlerin özeti. */
export function recentTestsSummary(
  results: readonly TestResult[],
  today: ISODate,
  windowDays: number = RECENT_TESTS_WINDOW_DAYS,
): RecentTestsSummary {
  const live = results.filter(isLive)
  const windowStart = addDays(today, -(Math.max(1, Math.floor(windowDays)) - 1))
  const dayOf = (result: TestResult) => toISODate(new Date(result.takenAt))
  const inWindow = live.filter((r) => dayOf(r) >= windowStart && dayOf(r) <= today)
  return {
    todayQuestions: inWindow
      .filter((r) => dayOf(r) === today)
      .reduce((total, r) => total + questionCount(r), 0),
    window: summarizeResults(inWindow),
    allTimeCount: live.length,
  }
}

/**
 * Tüm zamanların en zayıf `limit` konusu (tests calc `findWeakestTopics`, varsayılan soru eşiği
 * `MIN_QUESTIONS_FOR_WEAKNESS`). Silinmiş sonuçlar sayılmaz.
 */
export function weakestTopicsForToday(
  results: readonly TestResult[],
  limit: number = TODAY_WEAK_TOPIC_LIMIT,
): WeakTopic[] {
  return findWeakestTopics(summarizeByTopic(results.filter(isLive)), { limit })
}

// ---------------------------------------------------------------------------
// Kitaplar
// ---------------------------------------------------------------------------

/** Bugün kartında gösterilen en fazla kitap sayısı. */
export const TODAY_BOOK_LIMIT = 3

/**
 * Devam eden kitaplar: önce `inProgress`, sonra `notStarted`; her grupta girdi sırası korunur
 * (books calc `summarizeBooks` son etkinliğe göre sıralar). Bitmiş/arşivlenmiş hariç.
 */
export function booksInProgress(
  summaries: readonly BookSummary[],
  limit: number = TODAY_BOOK_LIMIT,
): BookSummary[] {
  const inProgress = summaries.filter((s) => s.status === 'inProgress')
  const notStarted = summaries.filter((s) => s.status === 'notStarted')
  return [...inProgress, ...notStarted].slice(0, Math.max(0, limit))
}

// ---------------------------------------------------------------------------
// Arkadaşlar
// ---------------------------------------------------------------------------

/**
 * Şu an odakta olan arkadaşlar (etkin durum 'focusing'; bayat durum çevrimdışı sayılır),
 * kullanıcı adına göre (tr-TR) sıralı. Girdi tipi geneldir: data katmanının `SocialFriend`'i uyar.
 */
export function focusingFriends<T extends { username: string; presence: SocialPresence | null }>(
  friends: readonly T[],
  now: Date,
): T[] {
  return friends
    .filter((friend) => effectivePresenceState(friend.presence, now) === 'focusing')
    .sort((a, b) => a.username.localeCompare(b.username, 'tr-TR'))
}
