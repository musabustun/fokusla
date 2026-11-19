import { Download, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useServices } from '@/data'
import { toISODate } from '@/domain'
import { ListRow, ListSection } from '@/ui'
import { ICON_CLASS } from './constants'
import { downloadJson } from './downloadJson'
import { useAsyncAction } from './useAsyncAction'

interface DataSectionProps {
  onRequestWipe: () => void
}

export function DataSection({ onRequestWipe }: DataSectionProps) {
  const { localData } = useServices()
  const { pending, error, run } = useAsyncAction()
  const [savedAs, setSavedAs] = useState<string | null>(null)

  const exportData = () =>
    run(async () => {
      setSavedAs(null)
      const backup = await localData.exportAll()
      const filename = `fokus-yedek-${toISODate(new Date(backup.exportedAt))}.json`
      downloadJson(filename, backup)
      setSavedAs(filename)
    })

  return (
    <ListSection
      header="Veri"
      footer={
        <>
          Tüm verilerini tek bir JSON dosyası olarak indirir. Dosya yalnızca cihazında oluşturulur.
          {savedAs ? (
            <p role="status" className="mt-1 text-success">
              Yedek indirildi: {savedAs}
            </p>
          ) : null}
          {error ? (
            <p role="alert" className="mt-1 text-danger">
              {error}
            </p>
          ) : null}
        </>
      }
    >
      <ListRow
        title="Verileri dışa aktar"
        subtitle="JSON olarak indir"
        icon={<Download className={ICON_CLASS} />}
        chevron={false}
        onClick={pending ? undefined : () => void exportData()}
      />
      <ListRow
        title={<span className="text-danger">Tüm verileri sil</span>}
        icon={<Trash2 className={`${ICON_CLASS} text-danger`} />}
        onClick={onRequestWipe}
      />
    </ListSection>
  )
}
