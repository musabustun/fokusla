import Charts
import FokusDesign
import FokusDomain
import SwiftUI

/// Günlük net trendi (web `NetTrendChart` + `TrendCard`): Swift Charts çizgi + nokta, sıfır çizgisi.
struct NetTrendSection: View {
    let results: [TestResultSnapshot]

    @Environment(\.fokusPalette) private var palette
    @Environment(\.calendar) private var calendar

    private var points: [NetTrendPoint] { TestsCalc.dailyNetTrend(results, calendar: calendar) }

    var body: some View {
        if !results.isEmpty {
            let points = points
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("NET TRENDİ")
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityHidden(true)
                chart(points)
                if points.count == 1 {
                    Text("Trend çizgisi için en az iki farklı günde test çöz.")
                        .fokusTextStyle(.footnote)
                        .foregroundStyle(.fkSecondaryLabel)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary(points))
            .accessibilityIdentifier("analysis.trend")
        }
    }

    private func day(_ point: NetTrendPoint) -> Date {
        let parts = point.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
            ?? .now
    }

    private func chart(_ points: [NetTrendPoint]) -> some View {
        let accent = FokusColor.color(.accentInk, palette: palette)
        let separator = FokusColor.color(.separator, palette: palette)
        let secondary = FokusColor.color(.secondaryLabel, palette: palette)
        let days = points.map(day)
        return Chart {
            RuleMark(y: .value("Sıfır", 0))
                .foregroundStyle(separator)
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                let value = point.summary.net
                if points.count > 1 {
                    LineMark(x: .value("Gün", days[index], unit: .day), y: .value("Net", value))
                        .foregroundStyle(accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                PointMark(x: .value("Gün", days[index], unit: .day), y: .value("Net", value))
                    .foregroundStyle(accent)
                    .symbolSize(36)
            }
        }
        .chartXScale(domain: xDomain(days))
        .chartYScale(domain: yDomain(points))
        .chartXAxis {
            // Az günde etiketler noktaların tam altında; çok günde otomatik aralık.
            if days.count <= 4 {
                AxisMarks(values: days) { value in dayLabel(value, color: secondary) }
            } else {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in dayLabel(value, color: secondary) }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(separator)
                if let net = value.as(Double.self) {
                    AxisValueLabel {
                        Text(AnalysisFormat.formatNet(net))
                            .fokusTextStyle(.caption)
                            .foregroundStyle(secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    @AxisMarkBuilder
    private func dayLabel(_ value: AxisValue, color: Color) -> some AxisMark {
        AxisValueLabel {
            if let date = value.as(Date.self) {
                Text(AnalysisFormat.formatShortDate(date, calendar: calendar))
                    .fokusTextStyle(.caption)
                    .foregroundStyle(color)
            }
        }
    }

    private func xDomain(_ days: [Date]) -> ClosedRange<Date> {
        guard let first = days.first, let last = days.last else { return Date.now...Date.now }
        let half: TimeInterval = days.count == 1 ? 86_400 : 43_200
        return first.addingTimeInterval(-half)...last.addingTimeInterval(half)
    }

    private func yDomain(_ points: [NetTrendPoint]) -> ClosedRange<Double> {
        let nets = points.map(\.summary.net) + [0]
        let low = nets.min() ?? 0
        let high = nets.max() ?? 0
        let pad = Swift.max((high - low) * 0.12, 1)
        return (low - pad)...(high + pad)
    }

    private func accessibilitySummary(_ points: [NetTrendPoint]) -> String {
        let last = points.last.map { AnalysisFormat.formatNet($0.summary.net) } ?? AnalysisFormat.formatNet(0)
        return "Net trendi: \(points.count) gün, son net \(last)"
    }
}
