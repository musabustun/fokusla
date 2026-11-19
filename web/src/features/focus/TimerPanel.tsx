import { Pause, Play, Square } from 'lucide-react'
import { useEffect, useState, type ReactNode, type Ref } from 'react'
import { Button, ProgressRing, cx } from '@/ui'
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
  idle: 'Hazır',
  focus: 'Odak',
  break: 'Mola',
}

const MS_PER_HOUR = 3_600_000
const RING_SIZE_PHONE = 300
const RING_SIZE_TABLET = 360
const RING_STROKE = 7
const DESKTOP_QUERY = '(min-width: 1024px)'

/** Halka çapı: iPhone 300, iPad (lg) 360. matchMedia yoksa (test ortamı) telefon boyutu. */
function useRingSize(): number {
  const [isWide, setIsWide] = useState(
    () => typeof window.matchMedia === 'function' && window.matchMedia(DESKTOP_QUERY).matches,
  )
  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return
    const query = window.matchMedia(DESKTOP_QUERY)
    const onChange = () => setIsWide(query.matches)
    query.addEventListener('change', onChange)
    return () => query.removeEventListener('change', onChange)
  }, [])
  return isWide ? RING_SIZE_TABLET : RING_SIZE_PHONE
}

/** Saatlik tur: geçen sürenin saat içindeki payı (0–1); yay her saniye hafifçe ilerler. */
function hourLap(ms: number): number {
  if (!Number.isFinite(ms) || ms <= 0) return 0
  return (ms % MS_PER_HOUR) / MS_PER_HOUR
}

function Clock({ phase, sessionFocusMs, breakMs }: TimerPanelProps) {
  const isRunning = phase === 'focus' || phase === 'break'
  const isBreak = phase === 'break'
  const text = formatClock(isBreak ? breakMs : isRunning ? sessionFocusMs : 0)
  // Saat hanesi varsa (7 karakter) iPhone halkasına sığması için bir kademe küçülür.
  const sizeClass = text.length > 5 ? 'text-numeral-xl lg:text-numeral-hero' : 'text-numeral-hero'
  const className = cx('numeric', sizeClass, isRunning ? 'text-label' : 'text-tertiary-label')
  if (!isRunning) {
    return (
      <div aria-hidden className={className}>
        {text}
      </div>
    )
  }
  return (
    <div role="timer" aria-label={isBreak ? 'Mola süresi' : 'Oturum süresi'} className={className}>
      {text}
    </div>
  )
}

function Dial(props: TimerPanelProps) {
  const { phase, sessionFocusMs, breakMs, sessionLabel } = props
  const ringSize = useRingSize()
  const isBreak = phase === 'break'
  const lap = hourLap(isBreak ? breakMs : phase === 'focus' ? sessionFocusMs : 0)
  return (
    <div className="flex flex-col items-center gap-4">
      <p
        className={cx(
          'flex items-center gap-2 eyebrow',
          phase === 'focus' && 'text-accent-ink',
          isBreak && 'text-success',
        )}
      >
        {phase === 'focus' && <span aria-hidden className="size-1.5 rounded-full bg-accent" />}
        {PHASE_LABEL[phase]}
      </p>
      {/* Halka dekoratif (aria-hidden); saat erişilebilir kalsın diye halkanın içinde değil üstünde. */}
      <div className="relative" style={{ width: ringSize, height: ringSize }}>
        <ProgressRing
          value={lap}
          size={ringSize}
          strokeWidth={RING_STROKE}
          tone={isBreak ? 'success' : 'accent'}
        />
        <div className="absolute inset-0 flex items-center justify-center">
          <Clock {...props} />
        </div>
      </div>
      <p className="min-h-5 text-center text-subheadline text-secondary-label">
        {sessionLabel && phase !== 'idle' ? sessionLabel : null}
      </p>
    </div>
  )
}

function Totals({ phase, sessionFocusMs, todayTotalMs }: TimerPanelProps) {
  return (
    <dl className="flex justify-center gap-10 border-y border-separator py-4 text-center">
      {phase === 'break' && (
        <div>
          <dt className="eyebrow">Bu oturumda odak</dt>
          <dd className="mt-1 numeric text-numeral-sm">{formatDurationText(sessionFocusMs)}</dd>
        </div>
      )}
      <div>
        <dt className="eyebrow">Bugün toplam</dt>
        <dd data-testid="today-total" className="mt-1 numeric text-numeral-sm">
          {formatDurationText(todayTotalMs)}
        </dd>
      </div>
    </dl>
  )
}

function Actions(props: TimerPanelProps) {
  const { phase, actionsRef, onStart, onPause, onResume, onFinish } = props
  if (phase === 'loading') return null
  const isIdle = phase === 'idle'
  const isFocus = phase === 'focus'
  const primary = isIdle
    ? { label: 'Odak başlat', icon: <Play aria-hidden className="size-5" />, onClick: onStart }
    : isFocus
      ? { label: 'Mola ver', icon: <Pause aria-hidden className="size-5" />, onClick: onPause }
      : { label: 'Devam et', icon: <Play aria-hidden className="size-5" />, onClick: onResume }
  // Birincil buton her durumda aynı konumda kalır (durum değişince klavye odağı korunur). Ana
  // eylem kehribar hap yalnızca boşta ("Odak başlat") ve molada ("Devam et"); odaktayken "Mola
  // ver" ve "Bitir" çizgili hap olur (ekranda en fazla bir kehribar eylem).
  return (
    <div ref={actionsRef} className="flex flex-col gap-3">
      <Button
        variant={isFocus ? 'tinted' : 'filled'}
        size="large"
        fullWidth
        icon={primary.icon}
        onClick={primary.onClick}
      >
        {primary.label}
      </Button>
      {!isIdle && (
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

/** Kronometre: durum, büyük halka + saat, bugünkü toplam ve eylemler. */
export function TimerPanel(props: TimerPanelProps) {
  const { phase, isLongBreak, error, picker, onResume, onFinish } = props
  return (
    <div aria-busy={phase === 'loading' || undefined} className="flex flex-col gap-8">
      <Dial {...props} />
      <Totals {...props} />
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
    </div>
  )
}
