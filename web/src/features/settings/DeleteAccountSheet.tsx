import { useState } from 'react'
import { useServices } from '@/data'
import { Button, Sheet } from '@/ui'
import { signOutAndUnlink } from './actions'
import { useAsyncAction } from './useAsyncAction'

interface DeleteAccountSheetProps {
  open: boolean
  onClose: () => void
  /** Hesap silindikten sonra oturum durumunu günceller. */
  onDeleted: () => void
  /** Kullanıcı cihazdaki verileri de silmek isterse çağrılır (onay akışı Veri bölümündedir). */
  onRequestWipe: () => void
}

type Step = 'confirm' | 'localData'

/**
 * Hesap silme: önce hesabı silmeyi onaylatır; ardından YEREL verilere ne olacağını AYRICA sorar.
 * Mock'ta yalnızca cihazdaki sahte Apple bağı kaldırılır.
 */
export function DeleteAccountSheet({
  open,
  onClose,
  onDeleted,
  onRequestWipe,
}: DeleteAccountSheetProps) {
  const services = useServices()
  const [step, setStep] = useState<Step>('confirm')
  const { pending, error, run } = useAsyncAction()

  const close = () => {
    setStep('confirm')
    onClose()
  }
  const deleteAccount = async () => {
    const done = await run(() => signOutAndUnlink(services, { deleteAccount: true }))
    if (done) {
      onDeleted()
      setStep('localData')
    }
  }
  const wipe = () => {
    setStep('confirm')
    onRequestWipe()
  }

  if (step === 'localData') {
    return (
      <Sheet
        open={open}
        onClose={close}
        title="Cihazdaki verilerin ne olsun?"
        description="Hesabın silindi. Kapatırsan verilerin bu cihazda kalır."
        footer={
          <div className="flex flex-col gap-2">
            <Button size="large" fullWidth onClick={close}>
              Verilerimi cihazda tut
            </Button>
            <Button variant="destructive" fullWidth onClick={wipe}>
              Cihazdaki verileri de sil…
            </Button>
          </div>
        }
      >
        <p className="pt-2 text-body text-secondary-label">
          Odak oturumların, test sonuçların, kitapların ve görevlerin hesaptan bağımsız olarak bu
          cihazda saklanıyor. İstersen bunları da silebilirsin; silmeden önce bir kez daha onayını
          isteyeceğiz.
        </p>
      </Sheet>
    )
  }

  return (
    <Sheet
      open={open}
      onClose={close}
      title="Hesabı sil"
      description="Bu işlem Apple hesabınla olan bağlantıyı kaldırır."
      footer={
        <div className="flex flex-col gap-2">
          <Button
            variant="destructive"
            size="large"
            fullWidth
            loading={pending}
            onClick={() => void deleteAccount()}
          >
            Hesabımı sil
          </Button>
          <Button variant="plain" fullWidth disabled={pending} onClick={close}>
            Vazgeç
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-3 pt-2 text-body text-secondary-label">
        <p>
          Hesabını silersen Apple ile giriş bağlantın kalkar ve iCloud senkronu kapanır. Bu
          cihazdaki verilerine ne olacağını bir sonraki adımda ayrıca soracağız.
        </p>
        <p>Fokus kendi sunucusunda veri tutmaz; silinecek bir sunucu verisi yoktur.</p>
        <p>Bu web prototipinde yalnızca cihazdaki sahte hesap bağlantısı kaldırılır.</p>
        {error ? (
          <p role="alert" className="text-subheadline text-danger">
            {error}
          </p>
        ) : null}
      </div>
    </Sheet>
  )
}
