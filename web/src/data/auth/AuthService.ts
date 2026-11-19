/**
 * Kimlik doğrulama sözleşmesi. Tek yöntem "Apple ile Giriş"tir ve ZORUNLU DEĞİLDİR.
 * Web prototipinde MockAuthService kullanılır; Swift'te AuthenticationServices
 * (ASAuthorizationAppleIDProvider) ile gerçeklenir.
 */
export interface AuthSession {
  /** Apple'ın uygulamaya özel stabil kullanıcı kimliği (ASAuthorizationAppleIDCredential.user). */
  appleUserId: string
  /** Apple yalnızca ilk girişte ad verir; sonra null olabilir. */
  displayName: string | null
  email: string | null
  /** Mock oturumlarda true. */
  isMock: boolean
}

export interface AuthService {
  /** Kayıtlı oturum; giriş yapılmadıysa null. */
  getSession(): Promise<AuthSession | null>
  /** "Apple ile Giriş". Kullanıcı iptal ederse AuthCancelledError fırlatır. */
  signInWithApple(): Promise<AuthSession>
  signOut(): Promise<void>
}

export class AuthCancelledError extends Error {
  constructor() {
    super('Giriş iptal edildi')
    this.name = 'AuthCancelledError'
  }
}
