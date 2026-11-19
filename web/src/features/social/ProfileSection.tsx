import { AtSign, Eye, Link2, Ticket } from 'lucide-react'
import { useId, useState } from 'react'
import { ROUTES } from '@/app/routes'
import { useServices, type SocialProfile } from '@/data'
import { Button, ListRow, ListSection, Sheet, Switch } from '@/ui'
import { inviteLink } from './format'
import { socialErrorMessage } from './socialErrors'
import { useCopyFeedback } from './useCopyFeedback'
import { UsernameForm } from './UsernameForm'

const ICON = 'size-5.5'

/** Kullanıcı adı, davet kodu/bağlantısı ve "Sosyalde görün" anahtarı. */
export function ProfileSection({ profile }: { profile: SocialProfile }) {
  const { social } = useServices()
  const visibilityLabelId = useId()
  const [isRenaming, setRenaming] = useState(false)
  const [visibilityError, setVisibilityError] = useState<string | null>(null)
  const { copied, failed, copy } = useCopyFeedback()
  const link = inviteLink(window.location.origin, ROUTES.social, profile.inviteCode)

  async function handleVisibility(next: boolean) {
    setVisibilityError(null)
    try {
      await social.setDiscoverable(next)
    } catch (caught) {
      setVisibilityError(socialErrorMessage(caught))
    }
  }

  const copyButton = (key: string, text: string, label: string) => (
    <Button variant="plain" size="small" onClick={() => copy(key, text)} aria-label={label}>
      {copied === key ? 'Kopyalandı' : failed === key ? 'Kopyalanamadı' : 'Kopyala'}
    </Button>
  )

  return (
    <>
      <ListSection
        header="Profil"
        footer={
          <>
            <span>
              Paylaşılan tek bilgi kullanıcı adın ve çalışma durumun/sürendir.
              {profile.isDiscoverable
                ? ' '
                : ' Şu an gizlisin: arkadaşların seni çevrimdışı görür ve kullanıcı adınla aranamazsın; davet kodun çalışmaya devam eder. '}
            </span>
            {visibilityError && (
              <span role="alert" className="text-danger">
                {visibilityError}
              </span>
            )}
          </>
        }
      >
        <ListRow
          title="Kullanıcı adı"
          icon={<AtSign className={ICON} />}
          value={`@${profile.username}`}
          onClick={() => setRenaming(true)}
        />
        <ListRow
          title="Davet kodu"
          icon={<Ticket className={ICON} />}
          subtitle={
            <span className="tracking-widest font-mono text-label">{profile.inviteCode}</span>
          }
          accessory={copyButton('code', profile.inviteCode, 'Davet kodunu kopyala')}
        />
        <ListRow
          title="Davet bağlantısı"
          icon={<Link2 className={ICON} />}
          subtitle={<span className="break-all">{link}</span>}
          accessory={copyButton('link', link, 'Davet bağlantısını kopyala')}
        />
        <ListRow
          title={<span id={visibilityLabelId}>Sosyalde görün</span>}
          icon={<Eye className={ICON} />}
          accessory={
            <Switch
              checked={profile.isDiscoverable}
              onChange={handleVisibility}
              aria-labelledby={visibilityLabelId}
            />
          }
        />
      </ListSection>
      <p aria-live="polite" className="sr-only">
        {copied ? 'Panoya kopyalandı' : ''}
      </p>
      <Sheet
        open={isRenaming}
        onClose={() => setRenaming(false)}
        title="Kullanıcı adını değiştir"
        description="Arkadaşların yeni adını görür; eski adın başkası tarafından alınabilir."
      >
        <UsernameForm
          initialValue={profile.username}
          submitLabel="Kaydet"
          onDone={() => setRenaming(false)}
        />
      </Sheet>
    </>
  )
}
