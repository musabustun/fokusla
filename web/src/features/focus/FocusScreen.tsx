import { useEffect, useRef, useState } from 'react'
import { useCurrentProfile } from '@/data'
import { toISODate, type FocusSegment, type FocusSession } from '@/domain'
import {
  computeSessionStats,
  dailyFocusTotalMs,
  dailyFocusTotals,
  getFocusPhase,
  isLongBreak,
  openSegmentDurationMs,
  recentDays,
  type FocusSessionStats,
} from '@/domain/calc/focus'
import { ScreenHeader } from '@/ui'
import { FocusStats } from './FocusStats'
import { buildHistoryRows } from './history'
import { SessionHistory } from './SessionHistory'
import { SessionSummarySheet } from './SessionSummarySheet'
import { SubjectPicker, type SubjectSelection } from './SubjectPicker'
import { subjectsForField } from './subjects'
import { TimerPanel, type TimerPhase } from './TimerPanel'
import { useFocusHistory } from './useFocusHistory'
import { useFocusSession, type ActiveFocus } from './useFocusSession'
import { useNow } from './useNow'

const NO_SELECTION: SubjectSelection = { subjectId: null, topicId: null }
const EMPTY_SESSIONS: FocusSession[] = []
const EMPTY_SEGMENTS: FocusSegment[] = []

function timerPhase(active: ActiveFocus | null | undefined): TimerPhase {
  if (active === undefined) return 'loading'
  if (active === null) return 'idle'
  const phase = getFocusPhase(active.session, active.segments)
  return phase === 'ended' ? 'idle' : phase
}

function sessionLabel(active: ActiveFocus | null | undefined): string | null {
  if (!active?.subject) return null
  return [active.subject.exam, active.subject.name, active.topic?.name].filter(Boolean).join(' · ')
}

/** Özet kapanınca odak, kaybolan "Bitir" yerine birincil eyleme ("Odak başlat") taşınır. */
function useRestoreFocusAfterSummary(isSummaryOpen: boolean) {
  const actionsRef = useRef<HTMLDivElement>(null)
  const wasOpen = useRef(false)
  useEffect(() => {
    if (isSummaryOpen) {
      wasOpen.current = true
      return
    }
    if (!wasOpen.current) return
    wasOpen.current = false
    actionsRef.current?.querySelector('button')?.focus()
  }, [isSummaryOpen])
  return actionsRef
}

export function FocusScreen() {
  const now = useNow()
  const profileState = useCurrentProfile()
  const history = useFocusHistory()
  const { active, error, start, pause, resume, finish } = useFocusSession()
  const [selection, setSelection] = useState<SubjectSelection>(NO_SELECTION)
  const [announcement, setAnnouncement] = useState('')
  const [summary, setSummary] = useState<FocusSessionStats | null>(null)
  const actionsRef = useRestoreFocusAfterSummary(summary !== null)

  const sessions = history?.sessions ?? EMPTY_SESSIONS
  const segments = history?.segments ?? EMPTY_SEGMENTS
  const activeSegments = active?.segments ?? EMPTY_SEGMENTS
  const phase = timerPhase(active)
  const todayTotalMs = dailyFocusTotalMs(sessions, segments, toISODate(now), now)
  const overall = computeSessionStats(segments, now)
  const field = profileState.status === 'ready' ? profileState.profile?.field : undefined

  const handleStart = async () => {
    if (await start(selection)) setAnnouncement('Odak başladı')
  }
  const handlePause = async () => {
    if (await pause()) setAnnouncement('Mola başladı')
  }
  const handleResume = async () => {
    if (await resume()) setAnnouncement('Odağa devam edildi')
  }
  const handleFinish = async () => {
    const stats = await finish()
    if (!stats) return
    setAnnouncement('Oturum bitti')
    setSummary(stats)
  }

  return (
    <>
      <ScreenHeader title="Odak" subtitle="Kronometre ve oturumlar" />
      <p role="status" className="sr-only">
        {announcement}
      </p>
      <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
        <div className="lg:sticky lg:top-6">
          <TimerPanel
            phase={phase}
            sessionFocusMs={computeSessionStats(activeSegments, now).focusMs}
            breakMs={openSegmentDurationMs(activeSegments, 'break', now)}
            todayTotalMs={todayTotalMs}
            sessionLabel={sessionLabel(active)}
            isLongBreak={phase === 'break' && isLongBreak(activeSegments, now)}
            error={error}
            actionsRef={actionsRef}
            picker={
              <SubjectPicker
                subjects={subjectsForField(history?.subjects ?? [], field)}
                value={selection}
                onChange={setSelection}
              />
            }
            onStart={() => void handleStart()}
            onPause={() => void handlePause()}
            onResume={() => void handleResume()}
            onFinish={() => void handleFinish()}
          />
        </div>
        <div className="flex flex-col gap-6">
          <FocusStats
            averageFocusMs={overall.averageFocusMs}
            averageBreakMs={overall.averageBreakMs}
            todayTotalMs={todayTotalMs}
            weeklyTotals={dailyFocusTotals(sessions, segments, recentDays(now), now)}
          />
          {history && <SessionHistory rows={buildHistoryRows(history, now)} />}
        </div>
      </div>
      <SessionSummarySheet stats={summary} onClose={() => setSummary(null)} />
    </>
  )
}
