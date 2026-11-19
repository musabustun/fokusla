/**
 * Analiz ekranı (/analiz). Seçim URL'dedir: ?ders=<subjectId>[&konu=<topicId>].
 * - <1024px: liste → ayrıntı akışı (genel bakış / ders / konu tam ekran, geri bağlantısıyla).
 * - ≥1024px (iPad yatay): bölünmüş görünüm — solda ders listesi, sağda ayrıntı bölmesi.
 *   Yalnızca CSS ile (`lg:`); her durumda sayfada tek bir `<h1>` vardır.
 */
import { Plus } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { Button, buttonStyles, EmptyState, ScreenHeader } from '@/ui'
import type { Subject, TestResult, Topic, UUID } from '@/domain'
import { AnalysisOverview } from './AnalysisOverview'
import { ANALYSIS_TITLE, analysisHref, readSelection } from './analysisLinks'
import { isCatalogEntity } from './subjects'
import { SubjectDetail } from './SubjectDetail'
import { SubjectList } from './SubjectList'
import { SubjectSheet } from './SubjectSheet'
import { TestResultSheet } from './TestResultSheet'
import { TopicDetail } from './TopicDetail'
import { TopicSheet } from './TopicSheet'
import { useAnalysisData, type AnalysisData } from './useAnalysisData'

type SheetState =
  | { kind: 'test'; result?: TestResult }
  | { kind: 'subject'; subject?: Subject }
  | { kind: 'topic'; subjectId: UUID; topic?: Topic }

interface Selection {
  subject: Subject | undefined
  topic: Topic | undefined
  isUnknownSubject: boolean
}

function resolveSelection(data: AnalysisData, params: URLSearchParams): Selection {
  const { subjectId, topicId } = readSelection(params)
  const subject = subjectId ? data.subjectsById.get(subjectId) : undefined
  const candidate = topicId ? data.topicsById.get(topicId) : undefined
  const topic = subject && candidate?.subjectId === subject.id ? candidate : undefined
  return { subject, topic, isUnknownSubject: Boolean(subjectId) && !subject }
}

function NotFound({ actions }: { actions: ReactNode }) {
  return (
    <>
      <ScreenHeader title={ANALYSIS_TITLE} actions={actions} />
      <EmptyState
        title="Ders bulunamadı"
        message="Bu ders silinmiş ya da alanında görünmüyor olabilir."
        action={
          <Link to={analysisHref()} className={buttonStyles({ variant: 'tinted' })}>
            Analize dön
          </Link>
        }
      />
    </>
  )
}

function countCustom(entities: readonly { catalogKey: string | null }[]): number {
  return entities.filter((e) => !isCatalogEntity(e)).length
}

export function AnalysisScreen() {
  const state = useAnalysisData()
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const [sheet, setSheet] = useState<SheetState | null>(null)
  const closeSheet = () => setSheet(null)

  if (state.status === 'loading') {
    return <ScreenHeader title={ANALYSIS_TITLE} subtitle="Yükleniyor…" />
  }

  const data = state
  const { subject, topic, isUnknownSubject } = resolveSelection(data, params)
  const openTest = (result?: TestResult) => setSheet({ kind: 'test', result })

  const actions = (
    <Button icon={<Plus aria-hidden />} onClick={() => openTest()}>
      Test ekle
    </Button>
  )

  const renderPane = () => {
    if (isUnknownSubject) return <NotFound actions={actions} />
    if (subject && topic) {
      return (
        <TopicDetail
          data={data}
          subject={subject}
          topic={topic}
          actions={actions}
          onAddTest={() => openTest()}
          onEditTopic={() => setSheet({ kind: 'topic', subjectId: subject.id, topic })}
          onEditResult={openTest}
        />
      )
    }
    if (subject) {
      return (
        <SubjectDetail
          data={data}
          subject={subject}
          actions={actions}
          onAddTopic={() => setSheet({ kind: 'topic', subjectId: subject.id })}
          onEditSubject={() => setSheet({ kind: 'subject', subject })}
          onEditResult={openTest}
        />
      )
    }
    return (
      <AnalysisOverview
        data={data}
        actions={actions}
        onAddTest={() => openTest()}
        onAddSubject={() => setSheet({ kind: 'subject' })}
      />
    )
  }

  const topicSheetSubjectId = sheet?.kind === 'topic' ? sheet.subjectId : subject?.id
  const topicsOfSheetSubject = topicSheetSubjectId
    ? (data.topicsBySubject.get(topicSheetSubjectId) ?? [])
    : []

  return (
    <div className="lg:flex lg:items-start lg:gap-6">
      <nav
        aria-label="Dersler"
        className="hidden lg:sticky lg:top-6 lg:block lg:max-h-[calc(100dvh-3rem)] lg:w-56 lg:shrink-0 lg:overflow-y-auto lg:pt-2"
      >
        <SubjectList
          compact
          subjects={data.subjects}
          subjectSummaries={data.subjectSummaries}
          selectedSubjectId={subject?.id ?? null}
          onAddSubject={() => setSheet({ kind: 'subject' })}
        />
      </nav>
      <div className="min-w-0 flex-1">{renderPane()}</div>

      <TestResultSheet
        open={sheet?.kind === 'test'}
        onClose={closeSheet}
        subjects={data.subjects}
        result={sheet?.kind === 'test' ? sheet.result : undefined}
        defaultSubjectId={subject?.id}
        defaultTopicId={topic?.id ?? null}
      />
      <SubjectSheet
        open={sheet?.kind === 'subject'}
        onClose={closeSheet}
        field={data.field}
        subject={sheet?.kind === 'subject' ? sheet.subject : undefined}
        existingCount={countCustom(data.subjects)}
        onSaved={(saved) => {
          if (sheet?.kind === 'subject' && !sheet.subject) {
            void navigate(analysisHref({ subjectId: saved.id }))
          }
        }}
        onDeleted={(id) => {
          if (id === subject?.id) void navigate(analysisHref(), { replace: true })
        }}
      />
      {topicSheetSubjectId && (
        <TopicSheet
          open={sheet?.kind === 'topic'}
          onClose={closeSheet}
          subjectId={topicSheetSubjectId}
          topic={sheet?.kind === 'topic' ? sheet.topic : undefined}
          existingCount={countCustom(topicsOfSheetSubject)}
          onDeleted={(id) => {
            if (id === topic?.id) {
              void navigate(analysisHref({ subjectId: topicSheetSubjectId }), { replace: true })
            }
          }}
        />
      )}
    </div>
  )
}
