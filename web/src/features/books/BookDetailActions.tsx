/** Kitap detayının eylem listesi: düzenle, rafa kaldır/geri al, sil (onaylı). */
import { Archive, ArchiveRestore, Pencil, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { Button, ListRow, ListSection, Sheet } from '@/ui'

export interface BookDetailActionsProps {
  isArchived: boolean
  onEdit: () => void
  onToggleArchive: () => void
  /** Onaydan sonra çağrılır. */
  onDelete: () => Promise<void>
}

export function BookDetailActions({
  isArchived,
  onEdit,
  onToggleArchive,
  onDelete,
}: BookDetailActionsProps) {
  const [isConfirmOpen, setConfirmOpen] = useState(false)
  const [isDeleting, setDeleting] = useState(false)
  const closeConfirm = () => setConfirmOpen(false)

  const handleConfirm = async () => {
    setDeleting(true)
    try {
      await onDelete()
    } finally {
      setDeleting(false)
      setConfirmOpen(false)
    }
  }

  return (
    <>
      <ListSection>
        <ListRow
          title="Düzenle"
          icon={<Pencil className="size-5" />}
          chevron={false}
          onClick={onEdit}
        />
        <ListRow
          title={isArchived ? 'Raftan geri al' : 'Rafa kaldır'}
          icon={isArchived ? <ArchiveRestore className="size-5" /> : <Archive className="size-5" />}
          chevron={false}
          onClick={onToggleArchive}
        />
        <ListRow
          title={<span className="text-danger">Kitabı sil</span>}
          icon={<Trash2 className="size-5 text-danger" />}
          chevron={false}
          onClick={() => setConfirmOpen(true)}
        />
      </ListSection>
      <Sheet
        open={isConfirmOpen}
        onClose={closeConfirm}
        title="Kitabı sil?"
        description="Kitap ve tüm ilerleme geçmişi silinecek."
        footer={
          <div className="flex flex-col gap-2">
            <Button
              variant="destructive"
              size="large"
              fullWidth
              loading={isDeleting}
              onClick={handleConfirm}
            >
              Sil
            </Button>
            <Button variant="plain" size="large" fullWidth onClick={closeConfirm}>
              Vazgeç
            </Button>
          </div>
        }
      >
        {null}
      </Sheet>
    </>
  )
}
