/**
 * Günlük net trendi için sade, kütüphanesiz SVG çizgi grafiği.
 * Çizim alanı `preserveAspectRatio="none"` ile genişliğe uyar; çizgi ve noktalar
 * `vector-effect="non-scaling-stroke"` sayesinde ölçeklenmez (noktalar yuvarlak uçlu sıfır
 * uzunluklu çizgilerdir, bu yüzden yatay esnemede de daire kalır). Etiketler HTML'dir.
 */
import type { NetTrendPoint } from '@/domain/calc/tests'
import { netDomain, PAD_Y, PLOT, scaleX, scaleY } from './chartScale'
import { formatNet, formatShortDay } from './format'

export interface NetTrendChartProps {
  points: readonly NetTrendPoint[]
  /** Grafiğin adı, ör. "Net trendi" — erişilebilir ad ve gizli tablonun başlığı olur. */
  label: string
}

function describe(points: readonly NetTrendPoint[], label: string): string {
  const last = points.at(-1)
  const lastNet = last ? formatNet(last.summary.net) : formatNet(0)
  return `${label}: ${points.length} gün, son net ${lastNet}`
}

export function NetTrendChart({ points, label }: NetTrendChartProps) {
  if (points.length === 0) return null

  const nets = points.map((p) => p.summary.net)
  const domain = netDomain(nets)
  const coords = points.map((p, i) => ({
    x: scaleX(i, points.length),
    y: scaleY(p.summary.net, domain),
  }))
  const linePath = coords.map((c, i) => `${i === 0 ? 'M' : 'L'}${c.x} ${c.y}`).join(' ')
  const zeroY = scaleY(0, domain)
  const first = points[0]
  const last = points.at(-1)

  return (
    <figure className="m-0">
      <div role="img" aria-label={describe(points, label)}>
        <div aria-hidden className="flex gap-2">
          <div className="relative h-32 w-12 shrink-0 text-right text-caption text-secondary-label tabular-nums">
            <span className="absolute top-[8%] right-0 -translate-y-1/2">
              {formatNet(domain.max)}
            </span>
            <span className="absolute right-0 bottom-[8%] translate-y-1/2">
              {formatNet(domain.min)}
            </span>
          </div>
          <svg
            viewBox={`0 0 ${PLOT} ${PLOT}`}
            preserveAspectRatio="none"
            className="h-32 w-full min-w-0 flex-1 overflow-visible"
            focusable="false"
          >
            <line
              x1={0}
              x2={PLOT}
              y1={PAD_Y}
              y2={PAD_Y}
              className="stroke-separator"
              strokeWidth={1}
              strokeDasharray="3 3"
              vectorEffect="non-scaling-stroke"
            />
            <line
              x1={0}
              x2={PLOT}
              y1={zeroY}
              y2={zeroY}
              className="stroke-separator"
              strokeWidth={1}
              vectorEffect="non-scaling-stroke"
              data-testid="zero-baseline"
            />
            {coords.length > 1 && (
              <path
                d={linePath}
                fill="none"
                className="stroke-accent-ink"
                strokeWidth={2}
                strokeLinejoin="round"
                strokeLinecap="round"
                vectorEffect="non-scaling-stroke"
              />
            )}
            {coords.map((c, i) => (
              <path
                key={points[i]?.date ?? i}
                d={`M${c.x} ${c.y} h0`}
                className="stroke-accent-ink"
                strokeWidth={8}
                strokeLinecap="round"
                vectorEffect="non-scaling-stroke"
                data-testid="trend-point"
              />
            ))}
          </svg>
        </div>
        <div
          aria-hidden
          className="mt-1 flex justify-between pl-14 text-caption text-secondary-label tabular-nums"
        >
          <span>{first ? formatShortDay(first.date) : null}</span>
          {last && points.length > 1 && <span>{formatShortDay(last.date)}</span>}
        </div>
      </div>
      <table className="sr-only">
        <caption>{label}</caption>
        <thead>
          <tr>
            <th scope="col">Gün</th>
            <th scope="col">Net</th>
          </tr>
        </thead>
        <tbody>
          {points.map((p) => (
            <tr key={p.date}>
              <th scope="row">{formatShortDay(p.date)}</th>
              <td>{formatNet(p.summary.net)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}
