import { useState } from 'react'
import { Button } from '@/ui'
import { DELETE_FAILED_MESSAGE } from './formStyles'

export interface DeleteConfirmProps {
  /** İkinci adımda gösterilen uyarı (ör. "Silmek istediğine emin misin?"). */
  message: string
  /** Onaylanınca çağrılır; reddedilirse hata mesajı gösterilir. */
  onConfirm: () => Promise<void>
  disabled?: boolean
}

/** İki adımlı silme: "Sil" → uyarı + "Vazgeç" / "Evet, sil". */
export function DeleteConfirm({ message, onConfirm, disabled = false }: DeleteConfirmProps) {
  const [isConfirming, setConfirming] = useState(false)
  const [isDeleting, setDeleting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const confirm = async () => {
    setDeleting(true)
    setError(null)
    try {
      await onConfirm()
    } catch (cause) {
      console.error(cause)
      setError(DELETE_FAILED_MESSAGE)
      setDeleting(false)
    }
  }

  if (!isConfirming) {
    return (
      <Button
        variant="destructive"
        fullWidth
        disabled={disabled}
        onClick={() => setConfirming(true)}
      >
        Sil
      </Button>
    )
  }
  return (
    <div className="flex flex-col gap-2">
      <p className="text-subheadline text-label">{message}</p>
      {error && (
        <p role="alert" className="text-footnote text-danger">
          {error}
        </p>
      )}
      <div className="flex gap-2">
        <Button
          variant="plain"
          fullWidth
          disabled={isDeleting}
          onClick={() => {
            setConfirming(false)
            setError(null)
          }}
        >
          Vazgeç
        </Button>
        <Button variant="destructive" fullWidth loading={isDeleting} onClick={() => void confirm()}>
          Evet, sil
        </Button>
      </div>
    </div>
  )
}
