import { useEffect, useState } from 'react'

const FEEDBACK_MS = 2000

/** Panoya kopyalar ve kısa bir "Kopyalandı" geri bildirimi için anahtarı tutar. */
export function useCopyFeedback() {
  const [copied, setCopied] = useState<string | null>(null)
  const [failed, setFailed] = useState<string | null>(null)

  useEffect(() => {
    if (!copied && !failed) return
    const id = setTimeout(() => {
      setCopied(null)
      setFailed(null)
    }, FEEDBACK_MS)
    return () => clearTimeout(id)
  }, [copied, failed])

  async function copy(key: string, text: string) {
    try {
      await navigator.clipboard.writeText(text)
      setFailed(null)
      setCopied(key)
    } catch (error) {
      console.warn('Panoya kopyalanamadı', error)
      setCopied(null)
      setFailed(key)
    }
  }

  return { copied, failed, copy }
}
