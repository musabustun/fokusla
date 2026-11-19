import { Cloud, RefreshCw } from 'lucide-react'
import { useServices, useSyncState, type AuthSession } from '@/data'
import { ListRow, ListSection, Switch } from '@/ui'
import { ICON_CLASS } from './constants'
import { formatSyncStatus } from './formatSyncStatus'
import { useAsyncAction } from './useAsyncAction'

interface SyncSectionProps {
  /** undefined: henüz okunuyor; null: giriş yapılmamış. */
  session: AuthSession | null | undefined
}

function syncFooter(isSignedIn: boolean, isEnabled: boolean): string {
  if (isEnabled) {
    return "Verilerin yalnızca iCloud hesabındaki özel alana gönderilir; Fokus'un sunucusu yoktur. Bu web prototipinde senkron simüle edilir."
  }
  if (isSignedIn) {
    return "Açarsan verilerin iCloud hesabınla iPhone ve iPad'in arasında eşitlenir."
  }
  return 'Senkron kapalı çünkü giriş yapmadın. iCloud senkronu için önce Apple ile giriş yap; girişsiz de her şey bu cihazda çalışır.'
}

export function SyncSection({ session }: SyncSectionProps) {
  const { sync } = useServices()
  const state = useSyncState()
  const { error, run } = useAsyncAction()
  const isEnabled = state.kind !== 'disabled'
  const isSignedIn = Boolean(session)
  // Girişsizken açılamaz; ama zaten açıksa (eski kayıt) kapatılabilmeli.
  const canToggle = session !== undefined && (isSignedIn || isEnabled)

  const toggle = (next: boolean) =>
    run(async () => {
      if (next) {
        await sync.enable()
        void sync.syncNow()
      } else {
        await sync.disable()
      }
    })

  return (
    <ListSection
      header="Senkronizasyon"
      footer={
        <>
          {syncFooter(isSignedIn, isEnabled)}
          {error ? (
            <p role="alert" className="mt-1 text-danger">
              {error}
            </p>
          ) : null}
        </>
      }
    >
      <ListRow
        title="iCloud senkronu"
        subtitle={<span role="status">{formatSyncStatus(state)}</span>}
        icon={<Cloud className={ICON_CLASS} />}
        accessory={
          <Switch
            aria-label="iCloud senkronu"
            checked={isEnabled}
            disabled={!canToggle}
            onChange={(next) => void toggle(next)}
          />
        }
      />
      {isEnabled ? (
        <ListRow
          title="Şimdi senkronize et"
          icon={<RefreshCw className={ICON_CLASS} />}
          chevron={false}
          onClick={state.kind === 'syncing' ? undefined : () => void run(() => sync.syncNow())}
        />
      ) : null}
    </ListSection>
  )
}
