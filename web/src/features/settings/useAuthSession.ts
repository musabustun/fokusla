import { useCallback, useEffect, useState } from 'react'
import { useServices, type AuthSession } from '@/data'

export interface UseAuthSessionResult {
  /** undefined: henüz okunuyor; null: giriş yapılmamış. */
  session: AuthSession | null | undefined
  setSession: (session: AuthSession | null) => void
}

/** Kayıtlı Apple oturumunu okur ve işlemlerden sonra güncellenmesine izin verir. */
export function useAuthSession(): UseAuthSessionResult {
  const { auth } = useServices()
  const [session, setSessionState] = useState<AuthSession | null | undefined>(undefined)

  useEffect(() => {
    let cancelled = false
    auth
      .getSession()
      .then((stored) => {
        if (!cancelled) setSessionState(stored)
      })
      .catch((error: unknown) => {
        console.error('Oturum okunamadı', error)
        if (!cancelled) setSessionState(null)
      })
    return () => {
      cancelled = true
    }
  }, [auth])

  const setSession = useCallback((next: AuthSession | null) => setSessionState(next), [])
  return { session, setSession }
}
