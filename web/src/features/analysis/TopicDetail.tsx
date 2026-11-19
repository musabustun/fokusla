import { NotebookPen, Pencil, Plus } from 'lucide-react'
import type { ReactNode } from 'react'
import { Button, EmptyState, ListSection, ScreenHeader } from '@/ui'
import type { Subject, TestResult, Topic } from '@/domain'
import { summarizeResults } from '@/domain/calc/tests'
import { analysisHref } from './analysisLinks'
import { BackLink } from './BackLink'
import { ResultRows } from './ResultRows'
import { isCatalogEntity } from './subjects'
import { SummaryCard } from './SummaryCard'
import { TrendCard } from './TrendCard'
import type { AnalysisData } from './useAnalysisData'

export interface TopicDetailProps {
  data: AnalysisData
  subject: Subject
  topic: Topic
  actions: ReactNode
  onAddTest: () => void
  onEditTopic: () => void
  onEditResult: (result: TestResult) => void
}

/** Konu ayrıntısı: özet, trend ve konunun tüm testleri (dokununca düzenlenir). */
export function TopicDetail({
  data,
  subject,
  topic,
  actions,
  onAddTest,
  onEditTopic,
  onEditResult,
}: TopicDetailProps) {
  const results = data.results.filter((r) => r.topicId === topic.id)
  const isCustom = !isCatalogEntity(topic)

  return (
    <>
      <BackLink to={analysisHref({ subjectId: subject.id })} label={subject.name} />
      <ScreenHeader title={topic.name} subtitle={subject.name} actions={actions} />
      {results.length === 0 ? (
        <EmptyState
          icon={<NotebookPen />}
          title="Bu konuda henüz test yok"
          message="Çözdüğün testin doğru, yanlış ve boş sayılarını gir; netin ve gelişimin burada görünür."
          action={
            <Button variant="tinted" icon={<Plus aria-hidden />} onClick={onAddTest}>
              İlk testini ekle
            </Button>
          }
        />
      ) : (
        <div className="space-y-6">
          <SummaryCard title="Konu özeti" summary={summarizeResults(results)} showLastTaken />
          <TrendCard results={results} />
          <ListSection header="Testler">
            <ResultRows results={results} booksById={data.booksById} onSelect={onEditResult} />
          </ListSection>
        </div>
      )}
      {isCustom && (
        <Button variant="plain" icon={<Pencil aria-hidden />} onClick={onEditTopic}>
          Konuyu düzenle
        </Button>
      )}
    </>
  )
}
