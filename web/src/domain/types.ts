/**
 * Fokus domain tipleri — TEK DOĞRULUK KAYNAĞI.
 *
 * Bu dosya web prototipi ile ileride yazılacak SwiftUI + SwiftData + CloudKit uygulaması
 * arasındaki sözleşmedir. Her tip docs/ARCHITECTURE.md içinde bir SwiftData @Model'e ve
 * CloudKit CKRecord tipine birebir eşlenir. Değiştirirken:
 *  - Alan ekle, alan SİLME/yeniden adlandırma (CloudKit şeması yalnızca eklemeye izin verir).
 *  - Yeni alanlar opsiyonel (`| null`) olsun; eski kayıtlarla uyumlu kalsın.
 *  - Türetilebilir değerleri (süre, net, ilerleme yüzdesi) SAKLAMA; domain/calc'te hesapla.
 *  - Kod tanımlayıcıları İngilizce, kullanıcıya görünen metinler Türkçedir.
 */

/**
 * RFC 4122 UUID, küçük harf (v4 rastgele; katalog kayıtları için v5 deterministik).
 * Swift: `UUID` (dikkat: `uuidString` BÜYÜK harf döner — karşılaştırmada lowercased() kullan).
 * CloudKit: CKSyncEngine ile `CKRecord.ID.recordName` olur; SwiftData'nın otomatik CloudKit
 * aynalaması kendi recordName'ini üretir, bu id ise sıradan bir alan olarak taşınır.
 */
export type UUID = string

/** ISO 8601 UTC zaman damgası, ör. `2026-11-19T07:30:00.000Z`. Swift: `Date`. */
export type ISODateTime = string

/** Yerel takvim günü `YYYY-MM-DD`, ör. `2026-11-19`. Swift: `String` (DateComponents'tan türetilir). */
export type ISODate = string

/** Senkronize edilen her kaydın ortak alanları. */
export interface BaseEntity {
  id: UUID
  createdAt: ISODateTime
  updatedAt: ISODateTime
  /** Soft delete: null değilse kayıt silinmiştir; senkron için tombstone olarak tutulur. */
  deletedAt: ISODateTime | null
}

/** Yeni kayıt girdisi: ortak alanları repository doldurur. */
export type NewEntity<T extends BaseEntity> = Omit<T, keyof BaseEntity>

/** Güncelleme yaması: ortak alanlar değiştirilemez. */
export type EntityPatch<T extends BaseEntity> = Partial<Omit<T, keyof BaseEntity>>

// ---------------------------------------------------------------------------
// Profil ve müfredat
// ---------------------------------------------------------------------------

/** YKS puan türü / alan. SOZ = Sözel, DIL = Yabancı Dil. */
export type YksField = 'SAY' | 'EA' | 'SOZ' | 'DIL'

/** Sınav oturumu. DİL alanı AYT yerine YDT'ye girer. */
export type ExamType = 'TYT' | 'AYT' | 'YDT'

export interface UserProfile extends BaseEntity {
  displayName: string | null
  field: YksField
  /** "Apple ile Giriş" yapıldıysa Apple'ın stabil kullanıcı kimliği; giriş atlandıysa null. */
  appleUserId: string | null
  /** Hedeflenen sınav yılı, ör. 2027. */
  targetExamYear: number | null
  /** Onboarding tamamlandığında set edilir; null ise onboarding gösterilir. */
  onboardingCompletedAt: ISODateTime | null
}

export interface Subject extends BaseEntity {
  name: string
  exam: ExamType
  /** Bu dersi sınavında gören alanlar. TYT dersleri için tüm alanlar. */
  fields: YksField[]
  /** Müfredat kataloğundan geldiyse stabil anahtar (ör. `tyt-matematik`); kullanıcı eklediyse null. */
  catalogKey: string | null
  order: number
}

export interface Topic extends BaseEntity {
  subjectId: UUID
  name: string
  /** Müfredat kataloğundan geldiyse stabil anahtar; kullanıcı eklediyse null. */
  catalogKey: string | null
  order: number
}

// ---------------------------------------------------------------------------
// Kitaplar
// ---------------------------------------------------------------------------

export type BookKind = 'lecture' | 'questionBank' | 'practiceExam' | 'other'

/** Kitapta ilerlemenin birimi. */
export type BookUnit = 'page' | 'test' | 'section'

export interface Book extends BaseEntity {
  title: string
  publisher: string | null
  kind: BookKind
  subjectId: UUID | null
  exam: ExamType | null
  unit: BookUnit
  /** Toplam birim sayısı (sayfa/test/bölüm). Bilinmiyorsa null. */
  totalUnits: number | null
  /** Kitap rafa kaldırıldıysa (bitti/bırakıldı) zaman damgası. */
  archivedAt: ISODateTime | null
}

/** Kitapta "nereye kadar gelindi" kaydı. Güncel konum = en son kayıt. */
export interface BookProgress extends BaseEntity {
  bookId: UUID
  /** Ulaşılan birim (ör. 120. sayfa, 14. test). */
  reachedUnit: number
  topicId: UUID | null
  recordedAt: ISODateTime
  note: string | null
}

// ---------------------------------------------------------------------------
// Test analizi
// ---------------------------------------------------------------------------

/** Çözülen bir test/deneme bölümünün sonucu. Net SAKLANMAZ: net = D − Y/4 (domain/calc). */
export interface TestResult extends BaseEntity {
  subjectId: UUID
  topicId: UUID | null
  bookId: UUID | null
  /** Serbest kaynak etiketi, ör. "Test 12" veya "3D Deneme 4". */
  label: string | null
  takenAt: ISODateTime
  correct: number
  wrong: number
  blank: number
  durationSeconds: number | null
  note: string | null
}

// ---------------------------------------------------------------------------
// Odak
// ---------------------------------------------------------------------------

/**
 * Bir odak oturumu. Süreler SAKLANMAZ; segmentlerin zaman damgalarından hesaplanır
 * (domain/calc/focus.ts). Aktif oturum: endedAt === null.
 */
export interface FocusSession extends BaseEntity {
  /** Ders seçimi opsiyoneldir. */
  subjectId: UUID | null
  topicId: UUID | null
  startedAt: ISODateTime
  endedAt: ISODateTime | null
  note: string | null
}

export type FocusSegmentKind = 'focus' | 'break'

/** Oturum içindeki kesintisiz bir odak ya da mola aralığı. Açık segment: endedAt === null. */
export interface FocusSegment extends BaseEntity {
  sessionId: UUID
  kind: FocusSegmentKind
  startedAt: ISODateTime
  endedAt: ISODateTime | null
}

// ---------------------------------------------------------------------------
// Görevler
// ---------------------------------------------------------------------------

export type TaskKind = 'routine' | 'assignment'

/** ISO hafta günü: 1 = Pazartesi … 7 = Pazar. */
export type Weekday = 1 | 2 | 3 | 4 | 5 | 6 | 7

/**
 * Rutin tekrar kuralı. `daily` için weekdays boştur; `weekly` için en az bir gün içerir.
 * Swift'e Codable bir struct olarak taşınır.
 */
export interface RecurrenceRule {
  frequency: 'daily' | 'weekly'
  weekdays: Weekday[]
}

export interface Task extends BaseEntity {
  title: string
  kind: TaskKind
  notes: string | null
  subjectId: UUID | null
  /** Yalnızca assignment: son tarih. */
  dueDate: ISODate | null
  /** Yalnızca routine: tekrar kuralı. */
  recurrence: RecurrenceRule | null
  /** Yalnızca assignment: tamamlanma zamanı. Rutinler için TaskCompletion kullanılır. */
  completedAt: ISODateTime | null
  order: number
}

/** Bir rutinin belirli bir günde tamamlanması. (taskId, date) çifti tekildir. */
export interface TaskCompletion extends BaseEntity {
  taskId: UUID
  date: ISODate
  completedAt: ISODateTime
}

// ---------------------------------------------------------------------------
// Sosyal (TASLAK — CloudKit public/shared DB ile tasarlanacak)
// ---------------------------------------------------------------------------

export type FriendStatus = 'pending' | 'accepted' | 'blocked'

export interface Friend extends BaseEntity {
  /** Karşı tarafın uygulama içi kimliği (CloudKit user record name). */
  remoteUserId: string
  displayName: string
  status: FriendStatus
}

/** Arkadaşlarla paralel odak odası. */
export interface Room extends BaseEntity {
  name: string
  hostUserId: string
  memberUserIds: string[]
  inviteCode: string
  startedAt: ISODateTime | null
  endedAt: ISODateTime | null
}

/** Sosyalde paylaşılan odak durumu: odakta / molada / çevrimdışı. */
export type PresenceState = 'focusing' | 'onBreak' | 'offline'

/**
 * Bir kullanıcının arkadaşlarıyla paylaştığı anlık durum. SAKLANAN bir varlık DEĞİLDİR
 * (BaseEntity yok): yayınlanan bir anlık görüntüdür. Gizlilik gereği yalnızca durum ve
 * süreler içerir — ders, konu, test, kitap ya da başka kişisel veri ASLA eklenmez.
 * Canlı süreler `now` ile domain/calc/social.ts'te hesaplanır.
 * CloudKit: oda bölgesindeki / public DB'deki `Presence` kaydı (bkz. docs/ARCHITECTURE.md 4.7).
 */
export interface SocialPresence {
  state: PresenceState
  /** Sürmekte olan odak oturumunun başlangıcı; çevrimdışıysa null. */
  sessionStartedAt: ISODateTime | null
  /** Mevcut durumun (odak ya da mola aralığının) başlangıcı; çevrimdışıysa null. */
  stateSince: ISODateTime | null
  /** `updatedAt` anına kadar bugün (yayınlayanın yerel günü) biriken toplam odak süresi (ms). */
  todayFocusMs: number
  /** Durumun yayınlandığı an. Canlı bugünkü toplam = todayFocusMs + (odaktaysa now − updatedAt). */
  updatedAt: ISODateTime
}

// ---------------------------------------------------------------------------
// Varlık kataloğu
// ---------------------------------------------------------------------------

/** Veri katmanındaki tüm varlıkların tip haritası. Tablo/CKRecord tipi adları bu anahtarlardır. */
export interface EntityMap {
  profiles: UserProfile
  subjects: Subject
  topics: Topic
  books: Book
  bookProgress: BookProgress
  testResults: TestResult
  focusSessions: FocusSession
  focusSegments: FocusSegment
  tasks: Task
  taskCompletions: TaskCompletion
  friends: Friend
  rooms: Room
}

export type EntityName = keyof EntityMap
