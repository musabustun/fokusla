import { EyeOff, ShieldCheck, Timer, Users } from 'lucide-react'
import { useState } from 'react'
import { useServices } from '@/data'
import { AppleSignInButton, Card } from '@/ui'
import { socialErrorMessage } from './socialErrors'

const POINTS = [
  { icon: Timer, text: 'Arkadaşlarının şu an odakta mı, molada mı olduğunu gör.' },
  { icon: Users, text: 'Paralel odak odalarında aynı anda çalışın.' },
  {
    icon: ShieldCheck,
    text: 'Yalnızca kullanıcı adın ve çalışma süren paylaşılır; ders, test ve kitapların cihazında kalır.',
  },
  { icon: EyeOff, text: 'İstediğin an kendini gizleyebilirsin.' },
] as const

/** Girişsiz kullanıcıya Sosyal'in ne olduğunu anlatır ve "Apple ile Giriş" ister. */
export function SignInGate() {
  const { auth, social } = useServices()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSignIn() {
    setBusy(true)
    setError(null)
    try {
      await auth.signInWithApple()
      await social.refresh()
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card className="mx-auto max-w-md">
      <h2 className="text-title3">Birlikte çalışmak için giriş yap</h2>
      <p className="mt-1 text-subheadline text-secondary-label">
        Arkadaşlarını bulabilmek için bir hesaba ihtiyaç var. Fokus'un geri kalanı girişsiz de tam
        çalışır.
      </p>
      <ul className="my-5 flex flex-col gap-3">
        {POINTS.map(({ icon: Icon, text }) => (
          <li key={text} className="flex items-start gap-3 text-subheadline">
            <Icon aria-hidden className="mt-0.5 size-5 shrink-0 text-accent" />
            <span>{text}</span>
          </li>
        ))}
      </ul>
      {error && (
        <p role="alert" className="mb-3 text-subheadline text-danger">
          {error}
        </p>
      )}
      <AppleSignInButton loading={busy} onClick={handleSignIn} />
    </Card>
  )
}
