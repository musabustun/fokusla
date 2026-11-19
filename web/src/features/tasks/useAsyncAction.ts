import { useCallback, useState } from 'react'

export const WRITE_ERROR_MESSAGE = 'Değişiklik kaydedilemedi. Lütfen tekrar dene.'

export interface AsyncAction {
  /** Son hatanın kullanıcıya gösterilecek metni (yoksa null). */
  error: string | null
  pending: boolean
  /** Eylemi çalıştırır; hata olursa günlüğe yazar ve `error`'u doldurur. Başarıda true. */
  run: (action: () => Promise<unknown>) => Promise<boolean>
  clearError: () => void
}

/** Repository yazmalarını sarar: hatalar yutulmaz, arayüzde gösterilir. */
export function useAsyncAction(): AsyncAction {
  const [error, setError] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  const run = useCallback(async (action: () => Promise<unknown>) => {
    setError(null)
    setPending(true)
    try {
      await action()
      return true
    } catch (cause) {
      console.error('Görev değişikliği kaydedilemedi', cause)
      setError(WRITE_ERROR_MESSAGE)
      return false
    } finally {
      setPending(false)
    }
  }, [])

  const clearError = useCallback(() => setError(null), [])
  return { error, pending, run, clearError }
}
