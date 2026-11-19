import { Pencil, Plus } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { Button, ListRow, ListSection, ScreenHeader } from '@/ui'
import type { Subject, TestResult } from '@/domain'
import { summarizeResults } from '@/domain/calc/tests'
import { ANALYSIS_TITLE, analysisHref } from './analysisLinks'
import { BackLink } from './BackLink'
import { topicDetailText, topicStatText } from './labels'
import { ResultRows } from './ResultRows'
import { isCatalogEntity } from './subjects'
import { SummaryCard } from './SummaryCard'
import { TrendCard } from './TrendCard'
import type { AnalysisData } from './useAnalysisData'

export interface SubjectDetailProps {
  data: AnalysisData
  subject: Subject
  actions: ReactNode
  onAddTopic: () => void
  onEditSubject: () => void
  onEditResult: (result: TestResult) => void
}

/** Ders ayrıntısı: özet, trend, tüm konular (hiç çalışılmamışlar dahil), konusuz testler. */
export function SubjectDetail({
  data,
  subject,
  actions,
  onAddTopic,
  onEditSubject,
  onEditResult,
}: SubjectDetailProps) {
  const results = data.results.filter((r) => r.subjectId === subject.id)
  const topics = data.topicsBySubject.get(subject.id) ?? []
  const untopiced = results.filter((r) => !r.topicId || !data.topicsById.has(r.topicId))
  const isCustom = !isCatalogEntity(subject)

  return (
    <>
      <BackLink to={analysisHref()} label={ANALYSIS_TITLE} className="lg:hidden" />
      <ScreenHeader title={subject.name} subtitle={subject.exam} actions={actions} />
      <div className="space-y-6">
        <SummaryCard title="Ders özeti" summary={summarizeResults(results)} showLastTaken />
        <TrendCard results={results} />
        <ListSection header="Konular">
          {topics.length === 0 && <ListRow title="Henüz konu yok" />}
          {topics.map((topic) => {
            const summary = data.topicSummaries.get(topic.id)
            return (
              <ListRow
                key={topic.id}
                title={topic.name}
                subtitle={topicDetailText(summary)}
                value={<span className="numeric text-label">{topicStatText(summary)}</span>}
                render={(props) => (
                  <Link
                    to={analysisHref({ subjectId: subject.id, topicId: topic.id })}
                    {...props}
                  />
                )}
              />
            )
          })}
        </ListSection>
      </div>
      {untopiced.length > 0 && (
        <ListSection
          header="Konu seçilmedi"
          footer="Bu testler bir konuya bağlanmadığı için konu listesinde sayılmaz."
        >
          <ResultRows results={untopiced} booksById={data.booksById} onSelect={onEditResult} />
        </ListSection>
      )}
      <div className="flex flex-wrap gap-3">
        <Button variant="tinted" icon={<Plus aria-hidden />} onClick={onAddTopic}>
          Konu ekle
        </Button>
        {isCustom && (
          <Button variant="plain" icon={<Pencil aria-hidden />} onClick={onEditSubject}>
            Dersi düzenle
          </Button>
        )}
      </div>
    </>
  )
}
