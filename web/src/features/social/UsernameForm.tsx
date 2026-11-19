import { useState, type FormEvent } from 'react'
import { useServices } from '@/data'
import { USERNAME_MAX_LENGTH, validateUsername } from '@/domain/calc/social'
import { Button } from '@/ui'
import { socialErrorMessage, USERNAME_PROBLEM_MESSAGES } from './socialErrors'
import { TextField } from './TextField'

interface UsernameFormProps {
  initialValue?: string
  submitLabel: string
  onDone?: () => void
}

const HINT =
  '3–20 karakter: küçük harf (a–z), rakam, nokta ve alt çizgi. Arkadaşların seni bu adla görür; gerçek adını ya da okulunu yazma.'

/** Benzersiz kullanıcı adı seçimi (ilk kurulum ve değiştirme). */
export function UsernameForm({ initialValue = '', submitLabel, onDone }: UsernameFormProps) {
  const { social } = useServices()
  const [value, setValue] = useState(initialValue)
  const [touched, setTouched] = useState(false)
  const [busy, setBusy] = useState(false)
  const [serverError, setServerError] = useState<string | null>(null)

  const validation = validateUsername(value)
  const formatError =
    touched && !validation.ok ? USERNAME_PROBLEM_MESSAGES[validation.problem] : null
  const error = serverError ?? formatError

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setTouched(true)
    if (!validation.ok) return
    setBusy(true)
    setServerError(null)
    try {
      const check = await social.checkUsername(value)
      if (!check.ok) {
        setServerError(USERNAME_PROBLEM_MESSAGES[check.problem])
        return
      }
      await social.claimUsername(check.username)
      onDone?.()
    } catch (caught) {
      setServerError(socialErrorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
      <TextField
        label="Kullanıcı adı"
        prefix="@"
        value={value}
        onValueChange={(next) => {
          setValue(next)
          setServerError(null)
        }}
        onBlur={() => setTouched(value.length > 0)}
        hint={HINT}
        error={error}
        autoComplete="off"
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        maxLength={USERNAME_MAX_LENGTH + 1}
        placeholder="ornek_ogrenci"
      />
      <Button type="submit" size="large" fullWidth loading={busy}>
        {submitLabel}
      </Button>
    </form>
  )
}
