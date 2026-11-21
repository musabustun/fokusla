import Charts
import FokusDesign
import FokusDomain
import SwiftUI

/// Odak istatistikleri: ortalama kesintisiz odak, ortalama mola ve son 7 günün çubuk grafiği.
struct FocusStatsSection: View {
    let averageFocusMs: Double
    let averageBreakMs: Double
    let weeklyTotals: [FocusCalc.DailyFocusTotal]

    private var weekTotalMs: Double { weeklyTotals.reduce(0) { $0 + $1.focusMs } }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                HStack(alignment: .top, spacing: 0) {
                    stat("Ortalama kesintisiz odak", ms: averageFocusMs, id: "focus.averageFocus")
                    Divider().overlay(.fkSeparator)
                    stat("Ortalama mola", ms: averageBreakMs, id: "focus.averageBreak")
                        .padding(.leading, FokusSpacing.lg)
                }
                .padding(.vertical, FokusSpacing.lg)
                .fixedSize(horizontal: false, vertical: true)
            }
            week
        }
    }

    private func stat(_ title: String, ms: Double, id: String) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            FocusDurationValue(ms: ms, style: .numeralLG)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(FocusFormat.durationText(ms))
        .accessibilityIdentifier(id)
    }

    // MARK: Son 7 gün

    private var week: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Son 7 gün").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(FocusFormat.durationText(weekTotalMs))
                    .fokusTextStyle(.numeralSM)
                    .foregroundStyle(.fkSecondaryLabel)
            }
            WeeklyFocusChart(totals: weeklyTotals)
        }
        // `.contain`: kapsayıcı kendi kimliğini alır, çocukların kimliklerini ezmez.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.week")
    }
}

/// "1 sa 5 dk" → büyük mono rakamlar + küçük, ikincil birimler.
struct FocusDurationValue: View {
    let ms: Double
    let style: FokusTextStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.xs) {
            ForEach(Array(FocusFormat.durationParts(ms).enumerated()), id: \.offset) { _, part in
                Text("\(part.value)").fokusTextStyle(style).foregroundStyle(.fkLabel)
                Text(part.unit)
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                    .padding(.trailing, FokusSpacing.xs)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Son günlerin odak süreleri (Swift Charts). Bugün kehribar; diğer günler nötr; boş günler yalnızca taban çizgisi.
struct WeeklyFocusChart: View {
    /// Eskiden yeniye; son eleman bugün.
    let totals: [FocusCalc.DailyFocusTotal]

    /// Sıfır olmayan günlerde çubuk görünür kalsın diye en küçük yükseklik (en yüksek değerin payı).
    private static let minBarFraction = 0.04
    private static let msPerMinute = 60_000.0

    private var maxMs: Double { totals.map(\.focusMs).max() ?? 0 }

    private func minutes(_ total: FocusCalc.DailyFocusTotal) -> Double {
        guard total.focusMs > 0, maxMs > 0 else { return 0 }
        return Swift.max(total.focusMs, maxMs * Self.minBarFraction) / Self.msPerMinute
    }

    private func barColor(_ total: FocusCalc.DailyFocusTotal) -> FokusColor {
        if total.day == totals.last?.day { return FokusColor(.accent) }
        return FokusColor(total.focusMs > 0 ? .separatorStrong : .separator)
    }

    var body: some View {
        Chart {
            ForEach(totals, id: \.day) { total in
                BarMark(x: .value("Gün", total.day), y: .value("Dakika", minutes(total)))
                    .foregroundStyle(barColor(total))
                    .clipShape(RoundedRectangle(cornerRadius: FokusRadius.sm))
            }
            RuleMark(y: .value("Taban", 0))
                .foregroundStyle(.fkSeparator)
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Swift.max(1, maxMs / Self.msPerMinute))
        .chartXAxis {
            AxisMarks(values: totals.map(\.day)) { value in
                AxisValueLabel(anchor: .top) {
                    if let day = value.as(String.self) {
                        Text(FocusDateFormat.weekdayShort(day))
                            .fokusTextStyle(.caption)
                            .foregroundStyle(day == totals.last?.day ? FokusColor(.label) : FokusColor(.secondaryLabel))
                    }
                }
            }
        }
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Son 7 gün")
        .accessibilityValue(
            totals.map { "\(FocusDateFormat.dayLabel($0.day)): \(FocusFormat.durationText($0.focusMs))" }
                .joined(separator: ", ")
        )
        .accessibilityIdentifier("focus.weekChart")
    }
}
