import { useId, useState, type FormEvent } from 'react'
import { useServices } from '@/data'
import type { UserProfile } from '@/domain'
import { Button, Sheet } from '@/ui'
import { saveDisplayName } from './actions'
import { DISPLAY_NAME_MAX_LENGTH } from './constants'
import { useAsyncAction } from './useAsyncAction'

interface DisplayNameSheetProps {
  open: boolean
  onClose: () => void
  profile: UserProfile
}

export function DisplayNameSheet({ open, onClose, profile }: DisplayNameSheetProps) {
  const formId = useId()
  const [draft, setDraft] = useState(profile.displayName ?? '')
  const { repositories } = useServices()
  const { pending, error, run } = useAsyncAction()

  const handleClose = () => {
    setDraft(profile.displayName ?? '')
    onClose()
  }
  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    if (await run(() => saveDisplayName({ repositories }, profile, draft))) onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={handleClose}
      title="Görünen ad"
      description="İstersen bir ad ekle; arkadaşların seni böyle görür. Boş bırakabilirsin."
      footer={
        <div className="flex flex-col gap-2">
          <Button type="submit" form={formId} size="large" fullWidth loading={pending}>
            Kaydet
          </Button>
          <Button variant="plain" fullWidth disabled={pending} onClick={handleClose}>
            Vazgeç
          </Button>
        </div>
      }
    >
      <form id={formId} onSubmit={handleSubmit} className="flex flex-col gap-2 pt-2">
        <label htmlFor={`${formId}-input`} className="text-subheadline text-secondary-label">
          Ad
        </label>
        <input
          id={`${formId}-input`}
          type="text"
          value={draft}
          maxLength={DISPLAY_NAME_MAX_LENGTH}
          autoComplete="nickname"
          placeholder="Adın"
          onChange={(event) => setDraft(event.target.value)}
          className="min-h-11 w-full rounded-md bg-fill px-3 text-body text-label placeholder:text-secondary-label"
        />
        {error ? (
          <p role="alert" className="text-subheadline text-danger">
            {error}
          </p>
        ) : null}
      </form>
    </Sheet>
  )
}
