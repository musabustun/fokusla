/**
 * Kitap ilerleme hesapları — SAF fonksiyonlar. Sahibi: books feature oturumu.
 *
 * Kurallar (Swift port'unda birebir korunur):
 *  - Hiçbir fonksiyon saati okumaz; "şimdi" gereken yerde `now: Date` parametre olarak gelir.
 *  - Girdiler mutasyona uğramaz; sıralama gereken yerde kopya sıralanır.
 *  - Soft-delete edilmiş kayıtlar (`deletedAt != null`) her hesapta yok sayılır.
 *  - Türetilmiş değerler (yüzde, hız, tahmini bitiş) SAKLANMAZ; her seferinde buradan hesaplanır.
 */
import type { Book, BookProgress, ISODateTime, UUID } from '../types'

/** Hız penceresi: son 7 gün. */
export const PACE_WINDOW_DAYS = 7
const DAY_MS = 24 * 60 * 60 * 1000

/**
 * Kitabın türetilmiş durumu.
 *  - `notStarted`: hiç ilerleme yok (ya da en son konum ≤ 0).
 *  - `inProgress`: ilerleme var, bitmedi, arşivde değil.
 *  - `completed`: toplam biliniyor (> 0) ve en son konum ≥ toplam (arşivde olsa da `completed`).
 *  - `archived`: bitmeden rafa kaldırıldı (`archivedAt != null`).
 */
export type BookStatus = 'notStarted' | 'inProgress' | 'completed' | 'archived'

/** Liste ve detay ekranlarının kullandığı, tek kitap için hesaplanmış özet. */
export interface BookSummary {
  book: Book
  /** En son ilerleme kaydı; yoksa undefined. */
  latest: BookProgress | undefined
  /** Ulaşılan birim; kayıt yoksa 0. */
  reachedUnit: number
  /** 0–1 ilerleme oranı (sınırlanmış); toplam bilinmiyorsa (null ya da ≤ 0) null. */
  ratio: number | null
  status: BookStatus
  /** Son ilerleme kaydının zamanı; yoksa null. */
  lastProgressAt: ISODateTime | null
  /** Son 7 gündeki ilerleme (birim/hafta); veri yetersizse null. Bkz. `weeklyPace`. */
  weeklyPace: number | null
  /** Bu hızla bitişe kalan gün; bkz. `estimateDaysToFinish`. */
  daysToFinish: number | null
  /** Sıralama anahtarı: max(book.updatedAt, son ilerleme zamanı). */
  activityAt: ISODateTime
}

/** Derse göre bir grup (subjectId null → "ders seçilmedi" grubu). */
export interface BookGroup {
  subjectId: UUID | null
  books: BookSummary[]
}

function isLive(entry: { deletedAt: ISODateTime | null }): boolean {
  return entry.deletedAt === null
}

/** recordedAt'e göre yeni → eski; eşitlikte createdAt'e göre yeni → eski. */
function compareNewestFirst(a: BookProgress, b: BookProgress): number {
  const byRecorded = Date.parse(b.recordedAt) - Date.parse(a.recordedAt)
  if (byRecorded !== 0) return byRecorded
  return Date.parse(b.createdAt) - Date.parse(a.createdAt)
}

/** Silinmemiş kayıtlar, en yeni önce (geçmiş listesi için). Girdi değişmez. */
export function sortProgressHistory(entries: readonly BookProgress[]): BookProgress[] {
  return entries.filter(isLive).sort(compareNewestFirst)
}

/** En son ilerleme kaydı (recordedAt'e göre; eşitlikte en son oluşturulan); yoksa undefined. */
export function latestProgress(entries: readonly BookProgress[]): BookProgress | undefined {
  return sortProgressHistory(entries)[0]
}

/** Geçerli toplam; null, 0, negatif ve sonlu olmayan değerler "bilinmiyor" (null) sayılır. */
export function knownTotal(book: Book): number | null {
  const total = book.totalUnits
  return total !== null && Number.isFinite(total) && total > 0 ? total : null
}

/** İlerleme oranı (0–1, sınırlanmış). Toplam bilinmiyorsa null. */
export function progressRatio(book: Book, latest: BookProgress | undefined): number | null {
  const total = knownTotal(book)
  if (total === null) return null
  const reached = latest?.reachedUnit ?? 0
  return Math.min(1, Math.max(0, reached / total))
}

/** Toplam biliniyor ve en son konum toplama ulaştı/aştı mı? */
export function isBookCompleted(book: Book, latest: BookProgress | undefined): boolean {
  const total = knownTotal(book)
  return total !== null && latest !== undefined && latest.reachedUnit >= total
}

/** Türetilmiş durum; öncelik: completed > archived > notStarted > inProgress. */
export function bookStatus(book: Book, latest: BookProgress | undefined): BookStatus {
  if (isBookCompleted(book, latest)) return 'completed'
  if (book.archivedAt !== null) return 'archived'
  if (latest === undefined || latest.reachedUnit <= 0) return 'notStarted'
  return 'inProgress'
}

/**
 * Son 7 gündeki ilerleme (birim/hafta), pencere = (now − 7 gün, now].
 *
 *  - Bitiş noktası: `now` anında veya öncesindeki en son kayıt (gelecek tarihli kayıtlar yok sayılır).
 *  - Başlangıç noktası: pencere başlangıcında veya öncesindeki en son kayıt; yoksa pencere
 *    içindeki en eski kayıt (ilk kayıt "takibe başladığım yer" sayılır, sıfırdan değil — yarısı
 *    bitmiş bir kitabı ekleyen kullanıcının hızı şişmesin).
 *  - Pencerede hiç kayıt yoksa ama öncesinde varsa: 0 (durmuş).
 *  - Hiç kullanılabilir kayıt yoksa ya da yalnızca tek kayıt varsa: null (hız hesaplanamaz).
 *  - Geri giden ilerleme (düzeltme) negatif hız üretmez: sonuç en az 0.
 */
export function weeklyPace(entries: readonly BookProgress[], now: Date): number | null {
  const nowMs = now.getTime()
  const windowStartMs = nowMs - PACE_WINDOW_DAYS * DAY_MS
  const usable = sortProgressHistory(entries).filter((e) => Date.parse(e.recordedAt) <= nowMs)
  const end = usable[0]
  if (end === undefined) return null

  const beforeWindow = usable.find((e) => Date.parse(e.recordedAt) <= windowStartMs)
  if (beforeWindow !== undefined) return Math.max(0, end.reachedUnit - beforeWindow.reachedUnit)

  const start = usable[usable.length - 1] ?? end
  if (start === end) return null
  return Math.max(0, end.reachedUnit - start.reachedUnit)
}

/**
 * Bu hızla bitişe kalan gün (yukarı yuvarlanır).
 *  - Kitap bitmişse (kalan ≤ 0) 0.
 *  - Toplam bilinmiyorsa, hız null ya da ≤ 0 ise null.
 */
export function estimateDaysToFinish(
  book: Book,
  latest: BookProgress | undefined,
  pacePerWeek: number | null,
): number | null {
  const total = knownTotal(book)
  if (total === null) return null
  const remaining = total - (latest?.reachedUnit ?? 0)
  if (remaining <= 0) return 0
  if (pacePerWeek === null || pacePerWeek <= 0) return null
  return Math.ceil(remaining / (pacePerWeek / PACE_WINDOW_DAYS))
}

function laterOf(a: ISODateTime, b: ISODateTime | null): ISODateTime {
  if (b === null) return a
  return Date.parse(b) > Date.parse(a) ? b : a
}

/** Tek kitap için tüm türetilmiş değerler. `entries` bu kitabın kayıtlarıdır (bookId filtreli). */
export function summarizeBook(
  book: Book,
  entries: readonly BookProgress[],
  now: Date,
): BookSummary {
  const latest = latestProgress(entries)
  const pace = weeklyPace(entries, now)
  const lastProgressAt = latest?.recordedAt ?? null
  return {
    book,
    latest,
    reachedUnit: latest?.reachedUnit ?? 0,
    ratio: progressRatio(book, latest),
    status: bookStatus(book, latest),
    lastProgressAt,
    weeklyPace: pace,
    daysToFinish: estimateDaysToFinish(book, latest, pace),
    activityAt: laterOf(book.updatedAt, lastProgressAt),
  }
}

/** activityAt'e göre yeni → eski; eşitlikte başlığa göre (tr-TR) alfabetik. */
function compareByActivity(a: BookSummary, b: BookSummary): number {
  const diff = Date.parse(b.activityAt) - Date.parse(a.activityAt)
  if (diff !== 0) return diff
  return a.book.title.localeCompare(b.book.title, 'tr-TR')
}

/**
 * Tüm kitapların özetleri, son etkinlik en üstte. Silinmiş kitaplar hariç; ilerleme kayıtları
 * `bookId` ile eşlenir (eşleşmeyen kayıtlar yok sayılır).
 */
export function summarizeBooks(
  books: readonly Book[],
  progress: readonly BookProgress[],
  now: Date,
): BookSummary[] {
  const byBook = new Map<UUID, BookProgress[]>()
  for (const entry of progress) {
    byBook.set(entry.bookId, [...(byBook.get(entry.bookId) ?? []), entry])
  }
  return books
    .filter(isLive)
    .map((book) => summarizeBook(book, byBook.get(book.id) ?? [], now))
    .sort(compareByActivity)
}

/** Bitti mi (tamamlandı ya da arşivlendi)? "Bitenler" sekmesi bunu kullanır. */
export function isFinished(summary: BookSummary): boolean {
  return summary.status === 'completed' || summary.status === 'archived'
}

/** Devam eden / bitenler ayrımı; her liste girdi sırasını korur. */
export function splitByFinished(summaries: readonly BookSummary[]): {
  active: BookSummary[]
  finished: BookSummary[]
} {
  return {
    active: summaries.filter((s) => !isFinished(s)),
    finished: summaries.filter(isFinished),
  }
}

/**
 * Derse göre gruplar. Gruplar en yeni etkinliklerine göre sıralanır; ders seçilmemiş
 * (subjectId null) grup her zaman en sondadır. Grup içi sıra: activityAt yeni → eski.
 */
export function groupBySubject(summaries: readonly BookSummary[]): BookGroup[] {
  const groups = new Map<UUID | null, BookSummary[]>()
  for (const summary of [...summaries].sort(compareByActivity)) {
    const key = summary.book.subjectId
    groups.set(key, [...(groups.get(key) ?? []), summary])
  }
  const all = [...groups.entries()].map(([subjectId, books]) => ({ subjectId, books }))
  return [...all.filter((g) => g.subjectId !== null), ...all.filter((g) => g.subjectId === null)]
}
