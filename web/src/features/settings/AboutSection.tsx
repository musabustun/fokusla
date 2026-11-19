import { Code, Info, Lock, Scale } from 'lucide-react'
import { ListRow, ListSection } from '@/ui'
import { APP_VERSION, ICON_CLASS, PRIVACY_SUMMARY, REPOSITORY_URL } from './constants'

export function AboutSection() {
  return (
    <ListSection header="Hakkında" footer="Fokus ücretsiz, reklamsız ve açık kaynaktır.">
      <ListRow title="Sürüm" icon={<Info className={ICON_CLASS} />} value={APP_VERSION} />
      <ListRow title="Lisans" icon={<Scale className={ICON_CLASS} />} value="MIT" />
      <ListRow
        title="Açık kaynak — GitHub"
        subtitle="github.com/musabustun/fokusla"
        icon={<Code className={ICON_CLASS} />}
        render={({ className, children }) => (
          <a href={REPOSITORY_URL} target="_blank" rel="noopener noreferrer" className={className}>
            {children}
            <span className="sr-only">(yeni sekmede açılır)</span>
          </a>
        )}
      />
      <ListRow title="Gizlilik" subtitle={PRIVACY_SUMMARY} icon={<Lock className={ICON_CLASS} />} />
    </ListSection>
  )
}
