import { useState, type FormEvent } from 'react'
import { useServices, type FriendLookup } from '@/data'
import { Button, SegmentedControl, Sheet, type SegmentedOption } from '@/ui'
import { socialErrorMessage } from './socialErrors'
import { TextField } from './TextField'

export type AddFriendMode = FriendLookup['kind']

const MODE_OPTIONS: readonly SegmentedOption<AddFriendMode>[] = [
  { value: 'username', label: 'Kullanıcı adı' },
  { value: 'inviteCode', label: 'Davet kodu' },
]

interface AddFriendSheetProps {
  open: boolean
  onClose: () => void
  initialMode?: AddFriendMode
  initialValue?: string
}

export function AddFriendSheet({ open, onClose, initialMode, initialValue }: AddFriendSheetProps) {
  return (
    <Sheet
      open={open}
      onClose={onClose}
      title="Arkadaş ekle"
      description="Arkadaşının kullanıcı adını ya da davet kodunu gir. İsteği kabul edince birbirinizin durumunu görürsünüz."
    >
      <AddFriendForm
        initialMode={initialMode ?? 'username'}
        initialValue={initialValue ?? ''}
        onDone={onClose}
      />
    </Sheet>
  )
}

interface AddFriendFormProps {
  initialMode: AddFriendMode
  initialValue: string
  onDone: () => void
}

function AddFriendForm({ initialMode, initialValue, onDone }: AddFriendFormProps) {
  const { social } = useServices()
  const [mode, setMode] = useState<AddFriendMode>(initialMode)
  const [value, setValue] = useState(initialValue)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const isUsername = mode === 'username'

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    const lookup: FriendLookup = isUsername
      ? { kind: 'username', username: value }
      : { kind: 'inviteCode', code: value }
    try {
      await social.sendFriendRequest(lookup)
      onDone()
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
      <SegmentedControl
        aria-label="Arama yöntemi"
        options={MODE_OPTIONS}
        value={mode}
        onChange={(next) => {
          setMode(next)
          setValue('')
          setError(null)
        }}
        fullWidth
      />
      <TextField
        label={isUsername ? 'Kullanıcı adı' : 'Davet kodu'}
        prefix={isUsername ? '@' : undefined}
        value={value}
        onValueChange={(next) => {
          setValue(next)
          setError(null)
        }}
        error={error}
        hint={isUsername ? undefined : '6 karakter, ör. K7M2QX'}
        autoComplete="off"
        autoCapitalize={isUsername ? 'none' : 'characters'}
        autoCorrect="off"
        spellCheck={false}
        placeholder={isUsername ? 'kullanici_adi' : 'K7M2QX'}
      />
      <Button type="submit" size="large" fullWidth loading={busy} disabled={value.trim() === ''}>
        İstek gönder
      </Button>
    </form>
  )
}
