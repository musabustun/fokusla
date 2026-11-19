import { AuthCancelledError, SocialError, type SocialErrorCode } from '@/data'
import type { UsernameProblem } from '@/domain/calc/social'

const SOCIAL_ERROR_MESSAGES: Record<SocialErrorCode, string> = {
  notSignedIn: 'Sosyal özellikler için Apple ile giriş yapmalısın.',
  noProfile: 'Önce bir kullanıcı adı seç.',
  invalidUsername: 'Kullanıcı adı geçersiz.',
  usernameTaken: 'Bu kullanıcı adı alınmış. Başka bir tane dene.',
  invalidInviteCode: 'Davet kodu 6 karakter olmalı (harf ve rakam).',
  userNotFound: 'Bu bilgilerle bir kullanıcı bulunamadı.',
  self: 'Kendini arkadaş olarak ekleyemezsin.',
  alreadyFriends: 'Bu kişi zaten arkadaşın.',
  requestExists: 'Bu kişiyle bekleyen bir istek zaten var.',
  requestNotFound: 'İstek artık geçerli değil.',
  friendNotFound: 'Bu kişi artık arkadaş listende değil.',
  roomNotFound: 'Oda bulunamadı ya da kapanmış.',
  invalidRoomName: 'Oda adı 1–40 karakter olmalı.',
}

export const USERNAME_PROBLEM_MESSAGES: Record<UsernameProblem | 'taken', string> = {
  tooShort: 'En az 3 karakter olmalı.',
  tooLong: 'En fazla 20 karakter olabilir.',
  invalidChars: 'Yalnızca küçük harf (a–z), rakam, nokta ve alt çizgi kullan.',
  mustStartWithLetter: 'Bir harfle başlamalı.',
  taken: 'Bu kullanıcı adı alınmış.',
}

/** Beklenen hataları Türkçe mesaja çevirir; beklenmeyenleri konsola yazar. */
export function socialErrorMessage(error: unknown): string {
  if (error instanceof SocialError) return SOCIAL_ERROR_MESSAGES[error.code]
  if (error instanceof AuthCancelledError) return 'Giriş iptal edildi.'
  console.error('Beklenmeyen sosyal hata', error)
  return 'Bir şeyler ters gitti. Lütfen tekrar dene.'
}
