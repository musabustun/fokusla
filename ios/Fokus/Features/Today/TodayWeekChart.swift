import Charts
import FokusDesign
import FokusDomain
import SwiftUI

/// Son 7 günün odak süreleri (Swift Charts). Bugün kehribar; diğer günler nötr; boş günler yalnızca taban çizgisi.
struct TodayWeekChart: View {
    /// Eskiden yeniye; son eleman bugün.
    let totals: [FocusCalc.DailyFocusTotal]

    /// Sıfır olmayan günlerde çubuk görünür kalsın diye en küçük yükseklik (en yüksek değerin payı).
    private static let minBarFraction = 0.04
    private static let msPerMinute = 60_000.0
    private static let chartHeight: CGFloat = 120

    private var maxMs: Double { totals.map(\.focusMs).max() ?? 0 }
    private var weekTotalMs: Double { totals.reduce(0) { $0 + $1.focusMs } }

    private func minutes(_ total: FocusCalc.DailyFocusTotal) -> Double {
        guard total.focusMs > 0, maxMs > 0 else { return 0 }
        return Swift.max(total.focusMs, maxMs * Self.minBarFraction) / Self.msPerMinute
    }

    private func barColor(_ total: FocusCalc.DailyFocusTotal) -> FokusColor {
        if total.day == totals.last?.day { return FokusColor(.accent) }
        return FokusColor(total.focusMs > 0 ? .separatorStrong : .separator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Son 7 gün").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(TodayDuration.text(weekTotalMs))
                    .fokusTextStyle(.numeralSM)
                    .foregroundStyle(.fkSecondaryLabel)
            }
            chart
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week")
    }

    private var chart: some View {
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
                        Text(TodayDayLabel.weekdayShort(day))
                            .fokusTextStyle(.caption)
                            .foregroundStyle(
                                day == totals.last?.day ? FokusColor(.label) : FokusColor(.secondaryLabel))
                    }
                }
            }
        }
        .frame(height: Self.chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Son 7 günün odak süreleri")
        .accessibilityValue(
            totals.map { "\(TodayDayLabel.weekdayLong($0.day)): \(FocusFormat.durationText($0.focusMs))" }
                .joined(separator: ", "))
        .accessibilityIdentifier("today.weekChart")
    }
}

/// Grafik eksen etiketleri (tr-TR): "Pzt" / "Pazartesi".
enum TodayDayLabel {
    static func weekdayShort(_ day: ISODate) -> String {
        TaskFormatting.weekdayShortName(TasksCalc.weekday(of: day))
    }

    static func weekdayLong(_ day: ISODate) -> String {
        TaskFormatting.weekdayLongName(TasksCalc.weekday(of: day))
    }
}
