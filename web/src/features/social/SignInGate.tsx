import { EyeOff, ShieldCheck, Timer, Users } from 'lucide-react'
import { useState } from 'react'
import { useServices } from '@/data'
import { AppleSignInButton } from '@/ui'
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
    <div className="mx-auto flex max-w-md flex-col gap-8 py-6">
      <div>
        <h2 className="text-title1">Birlikte çalışmak için giriş yap</h2>
        <p className="mt-3 text-callout text-secondary-label">
          Arkadaşlarını bulabilmek için bir hesaba ihtiyaç var. Fokus'un geri kalanı girişsiz de tam
          çalışır.
        </p>
      </div>
      <div className="flex flex-col gap-3">
        {error && (
          <p role="alert" className="text-subheadline text-danger">
            {error}
          </p>
        )}
        <AppleSignInButton loading={busy} onClick={handleSignIn} />
      </div>
      <ul className="border-t border-separator">
        {POINTS.map(({ icon: Icon, text }) => (
          <li
            key={text}
            className="flex items-start gap-3 border-b border-separator py-3 text-subheadline text-secondary-label"
          >
            <Icon aria-hidden className="mt-0.5 size-5 shrink-0" />
            <span>{text}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
