import { Apple, LogOut, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useServices, type AuthSession } from '@/data'
import { ListRow, ListSection } from '@/ui'
import { signInAndLink, signOutAndUnlink } from './actions'
import { ICON_CLASS } from './constants'
import { DeleteAccountSheet } from './DeleteAccountSheet'
import { useAsyncAction } from './useAsyncAction'

interface AccountSectionProps {
  /** undefined: henüz okunuyor; null: giriş yapılmamış. */
  session: AuthSession | null | undefined
  onSessionChange: (session: AuthSession | null) => void
  onRequestWipe: () => void
}

export function AccountSection({ session, onSessionChange, onRequestWipe }: AccountSectionProps) {
  const services = useServices()
  const { pending, error, run } = useAsyncAction()
  const [deleteOpen, setDeleteOpen] = useState(false)

  const signIn = () => run(async () => onSessionChange(await signInAndLink(services)))
  const signOut = () =>
    run(async () => {
      await signOutAndUnlink(services, { deleteAccount: false })
      onSessionChange(null)
    })

  return (
    <>
      {session === undefined ? null : session === null ? (
        <ListSection
          header="Hesap"
          footer={
            <>
              Giriş yapmadan da tüm özellikler cihazında çalışır.
              {error ? (
                <p role="alert" className="mt-1 text-danger">
                  {error}
                </p>
              ) : null}
            </>
          }
        >
          <ListRow
            title="Apple ile Giriş"
            subtitle="İsteğe bağlı; iCloud senkronu için gerekir"
            icon={<Apple className={ICON_CLASS} />}
            value={pending ? 'Giriş yapılıyor…' : undefined}
            onClick={pending ? undefined : () => void signIn()}
          />
        </ListSection>
      ) : (
        <ListSection
          header="Hesap"
          footer={
            <>
              Çıkış yapınca senkron kapanır; verilerin cihazında kalır.
              {error ? (
                <p role="alert" className="mt-1 text-danger">
                  {error}
                </p>
              ) : null}
            </>
          }
        >
          <ListRow
            title="Apple hesabı"
            subtitle={
              session.email ?? (session.isMock ? 'Prototip için sahte Apple oturumu' : undefined)
            }
            icon={<Apple className={ICON_CLASS} />}
            value={session.displayName ?? 'Giriş yapıldı'}
          />
          <ListRow
            title="Çıkış yap"
            icon={<LogOut className={ICON_CLASS} />}
            chevron={false}
            onClick={pending ? undefined : () => void signOut()}
          />
          <ListRow
            title={<span className="text-danger">Hesabı sil</span>}
            icon={<Trash2 className={`${ICON_CLASS} text-danger`} />}
            onClick={() => setDeleteOpen(true)}
          />
        </ListSection>
      )}
      <DeleteAccountSheet
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        onDeleted={() => onSessionChange(null)}
        onRequestWipe={onRequestWipe}
      />
    </>
  )
}
