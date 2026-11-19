import { ChartColumn, Plus } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { Button, EmptyState, ListRow, ListSection, ScreenHeader } from '@/ui'
import {
  findWeakestTopics,
  MIN_QUESTIONS_FOR_WEAKNESS,
  summarizeResults,
} from '@/domain/calc/tests'
import { ANALYSIS_TITLE, analysisHref } from './analysisLinks'
import { formatCount, formatQuestionCount } from './format'
import { topicStatText } from './labels'
import { SubjectList } from './SubjectList'
import { SummaryCard } from './SummaryCard'
import { TrendCard } from './TrendCard'
import type { AnalysisData } from './useAnalysisData'

export interface AnalysisOverviewProps {
  data: AnalysisData
  actions: ReactNode
  onAddTest: () => void
  onAddSubject: () => void
}

function WeakestTopics({ data }: { data: AnalysisData }) {
  const weakest = findWeakestTopics(data.topicSummaries)
  const footer = `En az ${formatCount(MIN_QUESTIONS_FOR_WEAKNESS)} soru çözülen konular gösterilir.`
  return (
    <ListSection header="En zayıf konular" footer={footer}>
      {weakest.length === 0 && <ListRow title="Yeterli veri yok" />}
      {weakest.map(({ topicId, summary }) => {
        const topic = data.topicsById.get(topicId)
        if (!topic) return null
        const subjectName = data.subjectsById.get(topic.subjectId)?.name ?? ''
        return (
          <ListRow
            key={topicId}
            title={topic.name}
            subtitle={`${subjectName} · ${formatQuestionCount(summary.totalQuestions)}`}
            value={<span className="tabular-nums">{topicStatText(summary)}</span>}
            render={(props) => (
              <Link to={analysisHref({ subjectId: topic.subjectId, topicId })} {...props} />
            )}
          />
        )
      })}
    </ListSection>
  )
}

/** Genel bakış: özet, net trendi, en zayıf konular; iPhone'da ayrıca ders listesi. */
export function AnalysisOverview({
  data,
  actions,
  onAddTest,
  onAddSubject,
}: AnalysisOverviewProps) {
  const hasResults = data.results.length > 0
  return (
    <>
      <ScreenHeader title={ANALYSIS_TITLE} subtitle="Deneme ve test sonuçların" actions={actions} />
      {hasResults ? (
        <div className="space-y-6">
          <SummaryCard title="Genel durum" summary={summarizeResults(data.results)} />
          <TrendCard results={data.results} />
          <WeakestTopics data={data} />
        </div>
      ) : (
        <EmptyState
          icon={<ChartColumn />}
          title="Henüz test kaydın yok"
          message="Çözdüğün testleri ders ve konu bazında kaydet: doğru, yanlış ve boş sayılarını gir; netin (D − Y/4) otomatik hesaplanır."
          action={
            <Button icon={<Plus aria-hidden />} onClick={onAddTest}>
              İlk testini ekle
            </Button>
          }
        />
      )}
      {/* iPad'de (lg) ders listesi sol bölmede; burada yalnızca dar ekranda gösterilir. */}
      <div className="lg:hidden">
        <SubjectList
          subjects={data.subjects}
          subjectSummaries={data.subjectSummaries}
          onAddSubject={onAddSubject}
        />
      </div>
    </>
  )
}
