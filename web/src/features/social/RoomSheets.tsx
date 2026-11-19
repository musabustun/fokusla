import { useState, type FormEvent } from 'react'
import { ROOM_NAME_MAX_LENGTH, useServices } from '@/data'
import { Button, Sheet } from '@/ui'
import { socialErrorMessage } from './socialErrors'
import { TextField } from './TextField'

interface SheetProps {
  open: boolean
  onClose: () => void
}

/** Yeni paralel odak odası. */
export function CreateRoomSheet({ open, onClose }: SheetProps) {
  return (
    <Sheet
      open={open}
      onClose={onClose}
      title="Oda oluştur"
      description="Arkadaşların odana katılır; herkes kendi kronometresiyle çalışır, durumlar canlı görünür."
    >
      <SingleFieldForm
        label="Oda adı"
        initialValue="Birlikte çalışalım"
        submitLabel="Oluştur"
        maxLength={ROOM_NAME_MAX_LENGTH}
        onSubmit={async (name, social) => {
          await social.createRoom(name)
        }}
        onDone={onClose}
      />
    </Sheet>
  )
}

/** Davet koduyla bir odaya katıl. */
export function JoinRoomSheet({ open, onClose }: SheetProps) {
  return (
    <Sheet
      open={open}
      onClose={onClose}
      title="Kodla katıl"
      description="Odanın 6 karakterlik davet kodunu gir."
    >
      <SingleFieldForm
        label="Oda davet kodu"
        initialValue=""
        submitLabel="Katıl"
        placeholder="K7M2QX"
        autoCapitalize="characters"
        onSubmit={async (code, social) => {
          await social.joinRoom({ kind: 'inviteCode', code })
        }}
        onDone={onClose}
      />
    </Sheet>
  )
}

type Social = ReturnType<typeof useServices>['social']

interface SingleFieldFormProps {
  label: string
  initialValue: string
  submitLabel: string
  placeholder?: string
  maxLength?: number
  autoCapitalize?: string
  onSubmit: (value: string, social: Social) => Promise<void>
  onDone: () => void
}

function SingleFieldForm({
  label,
  initialValue,
  submitLabel,
  placeholder,
  maxLength,
  autoCapitalize,
  onSubmit,
  onDone,
}: SingleFieldFormProps) {
  const { social } = useServices()
  const [value, setValue] = useState(initialValue)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await onSubmit(value, social)
      onDone()
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
      <TextField
        label={label}
        value={value}
        onValueChange={(next) => {
          setValue(next)
          setError(null)
        }}
        error={error}
        placeholder={placeholder}
        maxLength={maxLength}
        autoCapitalize={autoCapitalize}
        autoComplete="off"
        autoCorrect="off"
        spellCheck={false}
      />
      <Button type="submit" size="large" fullWidth loading={busy} disabled={value.trim() === ''}>
        {submitLabel}
      </Button>
    </form>
  )
}
