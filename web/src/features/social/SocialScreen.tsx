import { Card, ScreenHeader } from '@/ui'
import { useSocialSnapshot } from './hooks'
import { SignInGate } from './SignInGate'
import { SocialHome } from './SocialHome'
import { UsernameForm } from './UsernameForm'

/** Sosyal (`/sosyal`): giriş kapısı → kullanıcı adı → arkadaşlar ve paralel odak odaları. */
export function SocialScreen() {
  const snapshot = useSocialSnapshot()
  return (
    <>
      <ScreenHeader title="Sosyal" subtitle="Arkadaşlarınla aynı anda çalış" />
      <SocialContent snapshot={snapshot} />
    </>
  )
}

function SocialContent({ snapshot }: { snapshot: ReturnType<typeof useSocialSnapshot> }) {
  switch (snapshot.status) {
    case 'loading':
      return (
        <p role="status" className="text-subheadline text-secondary-label">
          Yükleniyor…
        </p>
      )
    case 'signedOut':
      return <SignInGate />
    case 'needsUsername':
      return (
        <Card className="mx-auto max-w-md">
          <h2 className="text-title3">Kullanıcı adını seç</h2>
          <p className="mt-1 mb-4 text-subheadline text-secondary-label">
            Arkadaşların seni yalnızca bu adla görür. Adın, e-postan ve çalışma içeriğin
            paylaşılmaz.
          </p>
          <UsernameForm submitLabel="Devam" />
        </Card>
      )
    case 'ready':
      return <SocialHome snapshot={snapshot} />
  }
}
