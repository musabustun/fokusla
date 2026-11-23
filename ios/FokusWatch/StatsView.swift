import FokusDesign
import FokusDomain
import SwiftUI

/// Oturum yokken açılan ekran: Başlat + bugünkü toplam ve hedef halkası, son 7 günün çubukları ve son
/// oturumlar (ders, süre). Değerler `WatchStatsCalc`'ten; telefondan gelen oturumlar da sayılır.
struct StatsView: View {
    @Environment(WatchModel.self) private var model

    #if DEBUG
    /// `-FokusWatchStatsBottom`: ekran görüntüsü için listeyi en alttan açar.
    private static let startsAtBottom = ProcessInfo.processInfo.arguments.contains("-FokusWatchStatsBottom")
    #else
    private static let startsAtBottom = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    model.start()
                } label: {
                    Label("Başlat", systemImage: "play.fill")
                }
                .buttonStyle(WatchPrimaryButtonStyle())
                .accessibilityIdentifier("watch.start")
                if model.actionFailed {
                    Text("Başlatılamadı").font(.caption2).foregroundStyle(.fkDanger)
                }
                if let stats = model.stats {
                    TodayCard(stats: stats)
                    WeekBars(stats: stats)
                    RecentList(stats: stats)
                }
            }
            .padding(.horizontal, 4)
        }
        .defaultScrollAnchor(Self.startsAtBottom ? .bottom : .top)
        .navigationTitle("Fokus")
    }
}

private struct TodayCard: View {
    let stats: WatchStatsCalc.Summary

    var body: some View {
        HStack(spacing: 10) {
            if let ratio = stats.goalRatio {
                ProgressRing(progress: ratio, lineWidth: 6) {
                    Text("%\(Int((ratio * 100).rounded()))")
                        .font(WatchFont.numeral(12)).foregroundStyle(.fkLabel)
                }
                .frame(width: 46, height: 46)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bugün").watchEyebrow()
                Text(FocusFormat.durationText(stats.todayMs))
                    .font(WatchFont.numeral(22)).foregroundStyle(.fkLabel)
                    .minimumScaleFactor(0.6).lineLimit(1)
                if let goal = stats.goalMinutes {
                    Text("Hedef \(FocusFormat.durationText(Double(goal) * 60_000))")
                        .font(.caption2).foregroundStyle(.fkSecondaryLabel)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WeekBars: View {
    let stats: WatchStatsCalc.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Son 7 gün").watchEyebrow()
                Spacer()
                Text(FocusFormat.durationText(stats.weekTotalMs))
                    .font(WatchFont.numeral(11)).foregroundStyle(.fkSecondaryLabel)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(stats.week.enumerated()), id: \.element.day) { index, day in
                    let isToday = index == stats.week.count - 1
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isToday ? AnyShapeStyle(FokusColor(.accent)) : AnyShapeStyle(FokusColor(.accentInk).opacity(0.55)))
                            .frame(width: 9, height: barHeight(day.focusMs))
                        Text(WatchDayLabel.short(day.day))
                            .font(.system(size: 9)).foregroundStyle(isToday ? .fkLabel : .fkTertiaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 52)
        }
        .accessibilityElement()
        .accessibilityLabel("Son 7 gün toplamı \(FocusFormat.durationText(stats.weekTotalMs))")
    }

    private func barHeight(_ ms: Double) -> CGFloat {
        guard stats.weekMaxMs > 0 else { return 3 }
        return max(3, CGFloat(ms / stats.weekMaxMs) * 38)
    }
}

private struct RecentList: View {
    @Environment(WatchModel.self) private var model
    let stats: WatchStatsCalc.Summary

    var body: some View {
        if !stats.recent.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Son oturumlar").watchEyebrow()
                ForEach(stats.recent) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(model.subjectName(for: session.subjectId) ?? "Odak")
                                .font(.footnote).foregroundStyle(.fkLabel).lineLimit(1)
                            Text(session.startedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption2).foregroundStyle(.fkSecondaryLabel)
                        }
                        Spacer(minLength: 4)
                        Text(FocusFormat.durationText(session.focusMs))
                            .font(WatchFont.numeral(13)).foregroundStyle(.fkAccentInk)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Çubuk altı gün harfi (Türkçe kısa gün adı, ör. "Pzt").
enum WatchDayLabel {
    static func short(_ day: ISODate) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).capitalized(with: Locale(identifier: "tr_TR"))
    }
}
