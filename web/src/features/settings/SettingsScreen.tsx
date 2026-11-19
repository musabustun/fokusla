import { useState } from 'react'
import { useCurrentProfile } from '@/data'
import { ScreenHeader } from '@/ui'
import { AboutSection } from './AboutSection'
import { AccountSection } from './AccountSection'
import { AppearanceSection } from './AppearanceSection'
import { DataSection } from './DataSection'
import { ProfileSection } from './ProfileSection'
import { SyncSection } from './SyncSection'
import { useAuthSession } from './useAuthSession'
import { WipeDataSheet } from './WipeDataSheet'

/** Ayarlar: iOS "Ayarlar" gibi gruplu liste (Profil, Hesap, Senkron, Görünüm, Veri, Hakkında). */
export function SettingsScreen() {
  const profileState = useCurrentProfile()
  const { session, setSession } = useAuthSession()
  const [wipeOpen, setWipeOpen] = useState(false)
  const profile = profileState.status === 'ready' ? profileState.profile : undefined
  const openWipe = () => setWipeOpen(true)

  return (
    // Tek sütunlu liste: geniş iPad/masaüstünde satırlar okunaklı genişlikte kalsın.
    <div className="max-w-3xl">
      <ScreenHeader title="Ayarlar" />
      {profile ? <ProfileSection profile={profile} /> : null}
      <AccountSection session={session} onSessionChange={setSession} onRequestWipe={openWipe} />
      <SyncSection session={session} />
      <AppearanceSection />
      <DataSection onRequestWipe={openWipe} />
      <AboutSection />
      <WipeDataSheet open={wipeOpen} onClose={() => setWipeOpen(false)} />
    </div>
  )
}
