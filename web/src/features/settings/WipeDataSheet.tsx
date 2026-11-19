import { useState } from 'react'
import { useServices } from '@/data'
import { Button, Sheet } from '@/ui'
import { wipeAllLocalData } from './actions'
import { useAsyncAction } from './useAsyncAction'

interface WipeDataSheetProps {
  open: boolean
  onClose: () => void
}

type Step = 'warn' | 'final'

/** Çift onaylı "tüm yerel verileri sil". Başarılı silmeden sonra kapı onboarding'e yönlendirir. */
export function WipeDataSheet({ open, onClose }: WipeDataSheetProps) {
  const services = useServices()
  const [step, setStep] = useState<Step>('warn')
  const { pending, error, run } = useAsyncAction()

  const close = () => {
    setStep('warn')
    onClose()
  }
  const wipe = async () => {
    if (await run(() => wipeAllLocalData(services))) close()
  }

  if (step === 'warn') {
    return (
      <Sheet
        open={open}
        onClose={close}
        title="Tüm veriler silinsin mi?"
        description="Bu cihazdaki bütün Fokus verisi silinir."
        footer={
          <div className="flex flex-col gap-2">
            <Button variant="destructive" size="large" fullWidth onClick={() => setStep('final')}>
              Devam
            </Button>
            <Button variant="plain" fullWidth onClick={close}>
              Vazgeç
            </Button>
          </div>
        }
      >
        <div className="flex flex-col gap-3 pt-2 text-body text-secondary-label">
          <p>
            Odak oturumların, test sonuçların, kitapların, görevlerin, profilin ve girişin silinir.
            Uygulama ilk açılış ekranına döner.
          </p>
          <p>Silmeden önce &ldquo;Verileri dışa aktar&rdquo; ile bir yedek almanı öneririz.</p>
          <p>iCloud senkronu açıksa silme diğer cihazlarına da yansıyabilir.</p>
        </div>
      </Sheet>
    )
  }

  return (
    <Sheet
      open={open}
      onClose={close}
      title="Emin misin?"
      description="Bu işlem geri alınamaz."
      footer={
        <div className="flex flex-col gap-2">
          <Button
            variant="destructive"
            size="large"
            fullWidth
            loading={pending}
            onClick={() => void wipe()}
          >
            Her şeyi kalıcı olarak sil
          </Button>
          <Button variant="plain" fullWidth disabled={pending} onClick={close}>
            Vazgeç
          </Button>
        </div>
      }
    >
      <div className="pt-2 text-body text-secondary-label">
        <p>Son onay: silinen veriler geri getirilemez.</p>
        {error ? (
          <p role="alert" className="mt-3 text-subheadline text-danger">
            {error}
          </p>
        ) : null}
      </div>
    </Sheet>
  )
}
