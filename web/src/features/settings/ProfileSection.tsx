import { GraduationCap, UserRound } from 'lucide-react'
import { useState } from 'react'
import { FIELD_LABELS } from '@/curriculum'
import type { UserProfile } from '@/domain'
import { ListRow, ListSection } from '@/ui'
import { ICON_CLASS } from './constants'
import { DisplayNameSheet } from './DisplayNameSheet'
import { FieldSheet } from './FieldSheet'

interface ProfileSectionProps {
  profile: UserProfile
}

export function ProfileSection({ profile }: ProfileSectionProps) {
  const [nameOpen, setNameOpen] = useState(false)
  const [fieldOpen, setFieldOpen] = useState(false)
  return (
    <>
      <ListSection
        header="Profil"
        footer="Alanını değiştirirsen AYT/YDT dersleri buna göre görünür; mevcut verilerin silinmez."
      >
        <ListRow
          title="Görünen ad"
          icon={<UserRound className={ICON_CLASS} />}
          value={profile.displayName ?? 'Eklenmedi'}
          onClick={() => setNameOpen(true)}
        />
        <ListRow
          title="YKS alanı"
          icon={<GraduationCap className={ICON_CLASS} />}
          value={FIELD_LABELS[profile.field]}
          onClick={() => setFieldOpen(true)}
        />
      </ListSection>
      <DisplayNameSheet open={nameOpen} onClose={() => setNameOpen(false)} profile={profile} />
      <FieldSheet open={fieldOpen} onClose={() => setFieldOpen(false)} profile={profile} />
    </>
  )
}
