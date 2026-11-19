import { Pause, Play, Square } from 'lucide-react'
import type { ReactNode, Ref } from 'react'
import { Button, Card, cx } from '@/ui'
import { formatClock, formatDurationText } from './formatDuration'
import { LongBreakAlert } from './LongBreakAlert'

export type TimerPhase = 'loading' | 'idle' | 'focus' | 'break'

export interface TimerPanelProps {
  phase: TimerPhase
  /** Bu oturumun toplam odak süresi (ms). */
  sessionFocusMs: number
  /** Açık molanın süresi (ms); molada değilse 0. */
  breakMs: number
  todayTotalMs: number
  /** Oturumun ders/konu etiketi (varsa). */
  sessionLabel: string | null
  isLongBreak: boolean
  error: string | null
  /** Boştayken gösterilen ders/konu seçici. */
  picker: ReactNode
  actionsRef?: Ref<HTMLDivElement>
  onStart: () => void
  onPause: () => void
  onResume: () => void
  onFinish: () => void
}

const PHASE_LABEL: Record<TimerPhase, string> = {
  loading: 'Yükleniyor',
  idle: 'Hazır olduğunda başla',
  focus: 'Odaktasın',
  break: 'Molada',
}

/** Büyük saat: large-title token'ının iki katı (ham boyut yok). */
const CLOCK_CLASS =
  'text-center text-[length:calc(var(--text-large-title)*2)] leading-none font-semibold tracking-tight tabular-nums'

function PhaseBadge({ phase }: { phase: TimerPhase }) {
  const isRunning = phase === 'focus' || phase === 'break'
  return (
    <p
      className={cx(
        'flex items-center justify-center gap-2 text-subheadline font-semibold',
        phase === 'focus' && 'text-accent-ink',
        phase === 'break' && 'text-warning',
        !isRunning && 'text-secondary-label',
      )}
    >
      {isRunning && (
        <span
          aria-hidden
          className={cx(
            'size-2 rounded-full',
            phase === 'focus' ? 'bg-accent motion-safe:animate-pulse' : 'bg-warning',
          )}
        />
      )}
      {PHASE_LABEL[phase]}
    </p>
  )
}

function Clock({ phase, sessionFocusMs, breakMs }: TimerPanelProps) {
  if (phase === 'focus' || phase === 'break') {
    const isBreak = phase === 'break'
    return (
      <div
        role="timer"
        aria-label={isBreak ? 'Mola süresi' : 'Oturum süresi'}
        className={CLOCK_CLASS}
      >
        {formatClock(isBreak ? breakMs : sessionFocusMs)}
      </div>
    )
  }
  return (
    <div aria-hidden className={cx(CLOCK_CLASS, 'text-tertiary-label')}>
      {formatClock(0)}
    </div>
  )
}

function Totals({ phase, sessionFocusMs, todayTotalMs }: TimerPanelProps) {
  return (
    <dl className="flex justify-center gap-8 text-center">
      {phase === 'break' && (
        <div>
          <dt className="text-footnote text-secondary-label">Bu oturumda odak</dt>
          <dd className="text-headline tabular-nums">{formatDurationText(sessionFocusMs)}</dd>
        </div>
      )}
      <div>
        <dt className="text-footnote text-secondary-label">Bugün toplam</dt>
        <dd data-testid="today-total" className="text-headline tabular-nums">
          {formatDurationText(todayTotalMs)}
        </dd>
      </div>
    </dl>
  )
}

function Actions(props: TimerPanelProps) {
  const { phase, actionsRef, onStart, onPause, onResume, onFinish } = props
  if (phase === 'loading') return null
  // Birincil buton her durumda aynı konumda kalır; böylece durum değişince klavye odağı korunur.
  const primary =
    phase === 'idle'
      ? { label: 'Odak başlat', icon: <Play aria-hidden className="size-5" />, onClick: onStart }
      : phase === 'focus'
        ? { label: 'Mola ver', icon: <Pause aria-hidden className="size-5" />, onClick: onPause }
        : { label: 'Devam et', icon: <Play aria-hidden className="size-5" />, onClick: onResume }
  return (
    <div ref={actionsRef} className="flex flex-col gap-3">
      <Button size="large" fullWidth icon={primary.icon} onClick={primary.onClick}>
        {primary.label}
      </Button>
      {phase !== 'idle' && (
        <Button
          variant="tinted"
          size="large"
          fullWidth
          icon={<Square aria-hidden className="size-5" />}
          onClick={onFinish}
        >
          Bitir
        </Button>
      )}
    </div>
  )
}

/** Kronometre kartı: durum, büyük saat, bugünkü toplam ve eylemler. */
export function TimerPanel(props: TimerPanelProps) {
  const { phase, sessionLabel, isLongBreak, error, picker, onResume, onFinish } = props
  return (
    <Card aria-busy={phase === 'loading' || undefined} className="flex flex-col gap-6 p-5">
      <div className="flex flex-col gap-3">
        <PhaseBadge phase={phase} />
        {sessionLabel && phase !== 'idle' && (
          <p className="text-center text-subheadline text-secondary-label">{sessionLabel}</p>
        )}
        <Clock {...props} />
        <Totals {...props} />
      </div>
      {phase === 'idle' && picker}
      {phase === 'break' && isLongBreak && (
        <LongBreakAlert onResume={onResume} onFinish={onFinish} />
      )}
      {error && (
        <p role="alert" className="text-center text-subheadline text-danger">
          {error}
        </p>
      )}
      {!(phase === 'break' && isLongBreak) && <Actions {...props} />}
    </Card>
  )
}
