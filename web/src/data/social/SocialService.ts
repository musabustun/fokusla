/**
 * Sosyal sözleşmesi: profil (kullanıcı adı, davet kodu, görünürlük), arkadaşlık istekleri,
 * arkadaş listesi ve paralel odak odaları.
 *
 * Web prototipinde MockSocialService kullanılır: HİÇBİR AĞ G/Ç'si YOKTUR, arkadaşlar ve odadaki
 * diğer kişiler zamanlayıcıyla simüle edilir. Native'de CloudKit (public DB + oda sahibinin
 * paylaşılan bölgesi) ile gerçeklenecek — eşleme: docs/ARCHITECTURE.md 4.7.
 *
 * Gizlilik (çoğu kullanıcı 18 yaş altı): başkalarına YALNIZCA kullanıcı adı ve odak durumu/süreleri
 * (SocialPresence) gider. Apple kimliği, ad, e-posta ve çalışma içeriği (ders, test, kitap) paylaşılmaz.
 *
 * Gerçek zamanlı değildir: arkadaşların durumu abonelik/push ile, gecikmeli gelir. UI süreleri
 * `updatedAt`/`stateSince` üzerinden yerelde ilerletir (domain/calc/social.ts).
 */
import type { ISODateTime, SocialPresence } from '@/domain'
import type { UsernameProblem } from '@/domain/calc/social'

/**
 *  - loading: henüz refresh() çalışmadı.
 *  - signedOut: "Apple ile Giriş" yapılmamış → Sosyal kapalı.
 *  - needsUsername: giriş var ama kullanıcı adı seçilmemiş.
 *  - ready: profil hazır.
 */
export type SocialStatus = 'loading' | 'signedOut' | 'needsUsername' | 'ready'

/** Başka kullanıcıların görebildiği TEK kimlik bilgisi. */
export interface SocialUser {
  /** Uygulama içi kullanıcı kimliği (CloudKit user record name). Kullanıcıya gösterilmez. */
  userId: string
  username: string
}

export interface SocialProfile extends SocialUser {
  /** 6 karakterlik davet kodu (A–Z, 0–9); kullanıcı adı gizliyken de arkadaş eklemeye yarar. */
  inviteCode: string
  /** "Sosyalde görün": false ise arkadaşlar beni çevrimdışı görür ve adımla aranamam. */
  isDiscoverable: boolean
}

export interface SocialFriend extends SocialUser {
  /** null: arkadaş gizlenmiş ya da hiç durum yayınlamamış (çevrimdışı gösterilir). */
  presence: SocialPresence | null
  friendsSince: ISODateTime
}

export type FriendRequestDirection = 'incoming' | 'outgoing'

export interface FriendRequest {
  id: string
  direction: FriendRequestDirection
  /** incoming: isteği gönderen; outgoing: isteğin gönderildiği kişi. */
  user: SocialUser
  createdAt: ISODateTime
}

export interface RoomMember extends SocialUser {
  isSelf: boolean
  isHost: boolean
  /** Kendi satırım için UI, focus verisinden hesaplanan güncel durumu kullanır. */
  presence: SocialPresence | null
  joinedAt: ISODateTime
}

/** İçinde bulunduğum paralel odak odası. Aynı anda en fazla bir odada olunur. */
export interface SocialRoom {
  id: string
  name: string
  hostUserId: string
  inviteCode: string
  /** Sıra: ev sahibi, sonra katılma zamanına göre. */
  members: readonly RoomMember[]
  createdAt: ISODateTime
}

/** Arkadaşların açık, katılınabilir odaları (içinde olmadığım). */
export interface RoomSummary {
  id: string
  name: string
  host: SocialUser
  memberCount: number
  /** Şu an odakta olan üye sayısı. */
  focusingCount: number
}

export interface SocialSnapshot {
  status: SocialStatus
  /** status 'ready' iken dolu; diğer durumlarda null. */
  profile: SocialProfile | null
  /** Kabul edilmiş arkadaşlar, kullanıcı adına göre sıralı. */
  friends: readonly SocialFriend[]
  /** Bekleyen istekler (gelen + giden), yeniden eskiye. */
  requests: readonly FriendRequest[]
  room: SocialRoom | null
  friendRooms: readonly RoomSummary[]
}

export type UsernameCheck =
  { ok: true; username: string } | { ok: false; problem: UsernameProblem | 'taken' }

/** Arkadaş ekleme: kullanıcı adıyla ya da davet koduyla. */
export type FriendLookup =
  { kind: 'username'; username: string } | { kind: 'inviteCode'; code: string }

export type RoomTarget = { kind: 'room'; roomId: string } | { kind: 'inviteCode'; code: string }

export type SocialErrorCode =
  | 'notSignedIn'
  | 'noProfile'
  | 'invalidUsername'
  | 'usernameTaken'
  | 'invalidInviteCode'
  | 'userNotFound'
  | 'self'
  | 'alreadyFriends'
  | 'requestExists'
  | 'requestNotFound'
  | 'friendNotFound'
  | 'roomNotFound'
  | 'invalidRoomName'

/** Sosyal işlemlerin beklenen hataları. UI `code`'a göre Türkçe mesaj gösterir. */
export class SocialError extends Error {
  readonly code: SocialErrorCode

  constructor(code: SocialErrorCode, message?: string) {
    super(message ?? code)
    this.name = 'SocialError'
    this.code = code
  }
}

export const ROOM_NAME_MAX_LENGTH = 40

export interface SocialService {
  /** Değişene kadar AYNI nesneyi döner (useSyncExternalStore için). */
  getSnapshot(): SocialSnapshot
  /**
   * Değişiklikleri dinler; aboneliği kaldıran fonksiyon döner.
   * Mock: ilk abone gelince simülasyon zamanlayıcısı başlar, son abone gidince durur.
   */
  subscribe(listener: () => void): () => void
  /** Oturumu (AuthService) ve profili yeniden okur. Giriş/çıkıştan sonra çağrılır. */
  refresh(): Promise<void>

  /** Biçim + tekillik kontrolü (mock: yerel liste; native: public DB'de recordName araması). */
  checkUsername(raw: string): Promise<UsernameCheck>
  /** Kullanıcı adını alır (ilk kez) ya da değiştirir. Hata: invalidUsername, usernameTaken, notSignedIn. */
  claimUsername(raw: string): Promise<SocialProfile>
  /** "Sosyalde görün / gizlen". */
  setDiscoverable(isDiscoverable: boolean): Promise<void>

  /** Hata: invalidUsername, invalidInviteCode, userNotFound, self, alreadyFriends, requestExists. */
  sendFriendRequest(lookup: FriendLookup): Promise<FriendRequest>
  /** Gelen isteği kabul/ret. Hata: requestNotFound. */
  respondToRequest(requestId: string, accept: boolean): Promise<void>
  /** Giden isteği geri çek. Hata: requestNotFound. */
  cancelRequest(requestId: string): Promise<void>
  /** Hata: friendNotFound. Ortak odadaysak oda üyeliği etkilenmez. */
  removeFriend(userId: string): Promise<void>

  /** Yeni oda açar ve içine girer (önceki odadan çıkılır). Ad 1–40 karakter. Hata: invalidRoomName. */
  createRoom(name: string): Promise<SocialRoom>
  /** Arkadaşın odasına ya da davet koduyla bir odaya katılır. Hata: roomNotFound, invalidInviteCode. */
  joinRoom(target: RoomTarget): Promise<SocialRoom>
  /** Odadan çıkar; ev sahibi çıkarsa oda kapanır. Odada değilse bir şey yapmaz. */
  leaveRoom(): Promise<void>

  /**
   * Kendi durumumu yayınlar (focus verisinden ownPresenceFromFocus ile üretilir).
   * isDiscoverable false ise hiçbir şey paylaşılmaz. Native: ~60 sn'lik kalp atışı + durum değişiminde.
   */
  publishPresence(presence: SocialPresence): Promise<void>
}
