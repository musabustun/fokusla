import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

@main
struct FokusWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusComplication()
    }
}

/// Komplikasyon girdisi: bir andaki odak özeti + sıradaki görev. `isAvailable == false` → depo henüz
/// paylaşılmadı (saat uygulaması bir kez açılmadı).
struct ComplicationEntry: TimelineEntry {
    var date: Date
    var focus: WidgetCalc.FocusSummary
    var nextTask: String?
    var tasksComplete: Bool
    var isAvailable: Bool

    static let unavailable = ComplicationEntry(
        date: .now, focus: .init(focusMs: 0, isRunning: false, goal: nil, timerStart: nil),
        nextTask: nil, tasksComplete: false, isAvailable: false)

    static func sample(now: Date = .now) -> ComplicationEntry {
        let focusMs = 2 * 3_600_000.0 + 15 * 60_000
        return ComplicationEntry(
            date: now,
            focus: .init(
                focusMs: focusMs, isRunning: false,
                goal: DailyGoalCalc.progress(focusMs: focusMs, goalMinutes: 210), timerStart: nil),
            nextTask: "Paragraf — 20 soru", tasksComplete: false, isAvailable: true)
    }
}

/// Zaman çizelgesi iOS widget'larıyla aynı kuralı kullanır (`WidgetCalc.timelinePlan`): odak sürerken 5 dk
/// aralıklı girdiler (halka ilerler; sayaç sistemce sayılır), değilken tek girdi ve gece yarısı yenileme.
/// Saat uygulaması her yazmadan sonra `reloadAllTimelines` çağırır.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ComplicationEntry) -> Void) {
        if context.isPreview {
            completion(.sample())
            return
        }
        Task { @MainActor in completion(Self.entries(at: [.now]).first ?? .unavailable) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ComplicationEntry>) -> Void) {
        Task { @MainActor in
            let running = (try? FokusSystem.snapshot().focus.isRunning) ?? false
            let plan = WidgetCalc.timelinePlan(isRunning: running, now: .now)
            let entries = Self.entries(at: plan.entries)
            completion(
                Timeline(entries: entries.isEmpty ? [.unavailable] : entries, policy: .after(plan.reloadAfter)))
        }
    }

    @MainActor
    static func entries(at dates: [Date]) -> [ComplicationEntry] {
        dates.compactMap { date in
            guard let snapshot = try? FokusSystem.snapshot(now: date) else { return nil }
            return ComplicationEntry(
                date: date, focus: snapshot.focus, nextTask: snapshot.tasks.next?.title,
                tasksComplete: snapshot.tasks.isComplete, isAvailable: true)
        }
    }
}

struct FocusComplication: Widget {
    static let kind = "FokusWatchFocus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.fkBackground, for: .widget)
        }
        .configurationDisplayName("Bugünkü odak")
        .description("Bugünkü odak süren, günlük hedef halkan ve sürüyorsa sayaç.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct ComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    private var ratio: Double { entry.focus.ratio }
    private var percent: Int { Int((ratio * 100).rounded()) }
    private var minutes: Int { Int(entry.focus.focusMs / 60_000) }
    private var totalText: String { FocusFormat.durationText(entry.focus.focusMs) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryInline: inline
        default: rectangular
        }
    }

    // MARK: Dairesel — hedef halkası

    private var circular: some View {
        Gauge(value: ratio) {
            Image(systemName: "timer")
        } currentValueLabel: {
            Text(entry.focus.goal != nil ? "\(percent)" : "\(minutes)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(FokusColor.color(.accentInk))
        .widgetAccentable()
    }

    // MARK: Dikdörtgen — toplam (sürüyorsa sayaç) + hedef + sıradaki görev

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "timer").widgetAccentable()
                if let start = entry.focus.timerStart {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
                } else {
                    Text(totalText).monospacedDigit()
                }
            }
            .font(.headline)
            if let goal = entry.focus.goal {
                Gauge(value: goal.ratio) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(FokusColor.color(.accentInk))
                    .widgetAccentable()
            }
            Text(entry.isAvailable ? (entry.nextTask ?? (entry.tasksComplete ? "Görevler tamam" : "Görev yok")) : "Fokus'u bir kez aç")
                .font(.caption).lineLimit(1)
        }
    }

    // MARK: Köşe — dakika + eğri hedef çubuğu

    private var corner: some View {
        Text(entry.focus.goal != nil ? "\(percent)%" : "\(minutes) dk")
            .font(.title3).monospacedDigit()
            .widgetCurvesContent()
            .widgetLabel {
                ProgressView(value: ratio).tint(FokusColor.color(.accentInk))
            }
            .widgetAccentable()
    }

    // MARK: Satır içi

    private var inline: some View {
        let text = entry.focus.goal.map { "\(totalText) · \(DailyGoalCalc.remainingText($0))" } ?? totalText
        return Label(text, systemImage: "timer")
    }
}
