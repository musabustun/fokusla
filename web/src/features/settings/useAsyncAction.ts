import { useCallback, useState } from 'react'
import { AuthCancelledError } from '@/data'
import { GENERIC_ERROR } from './constants'

export interface AsyncAction {
  pending: boolean
  error: string | null
  /** İşlemi çalıştırır; başarılıysa true döner. Kullanıcı iptali sessizce false döner. */
  run: (action: () => Promise<unknown>) => Promise<boolean>
  clearError: () => void
}

/** Bekleme + hata durumunu yöneten küçük yardımcı. Aynı anda tek işlem çalışır. */
export function useAsyncAction(): AsyncAction {
  const [pending, setPending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const run = useCallback(
    async (action: () => Promise<unknown>): Promise<boolean> => {
      if (pending) return false
      setPending(true)
      setError(null)
      try {
        await action()
        return true
      } catch (caught: unknown) {
        if (!(caught instanceof AuthCancelledError)) {
          console.error('Ayarlar işlemi başarısız', caught)
          setError(GENERIC_ERROR)
        }
        return false
      } finally {
        setPending(false)
      }
    },
    [pending],
  )
  const clearError = useCallback(() => setError(null), [])
  return { pending, error, run, clearError }
}
