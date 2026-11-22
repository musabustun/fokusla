import AppIntents
import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

@main
struct FokusWidgetsBundle: WidgetBundle {
    init() { FokusFonts.registerAll() }

    var body: some Widget {
        FocusGoalWidget()
        TasksWidget()
        FocusLiveActivityWidget()
    }
}

/// Widget girdisi: bir andaki odak özeti + bugünün görevleri. `isAvailable == false` → veri henüz
/// paylaşılmadı (uygulama bir kez açılmadı); görünümler "Fokus'u aç" durumunu gösterir.
struct FokusEntry: TimelineEntry {
    var date: Date
    var focus: WidgetCalc.FocusSummary
    var tasks: WidgetCalc.TaskList
    var isAvailable: Bool

    static let unavailable = FokusEntry(
        date: .now,
        focus: .init(focusMs: 0, isRunning: false, goal: nil, timerStart: nil),
        tasks: .init(items: [], done: 0, total: 0), isAvailable: false)

    /// Galeri/önizleme örneği.
    static func sample(now: Date = .now) -> FokusEntry {
        let items = [
            WidgetCalc.TaskItem(
                id: UUID(), title: "Paragraf — 20 soru", isDone: false, canToggle: true,
                subjectName: "TYT Türkçe", dueText: "Bugün", isOverdue: false),
            WidgetCalc.TaskItem(
                id: UUID(), title: "Limit tekrarı", isDone: false, canToggle: true,
                subjectName: "AYT Matematik", dueText: nil, isOverdue: false),
            WidgetCalc.TaskItem(
                id: UUID(), title: "Kitap okuma", isDone: true, canToggle: true,
                subjectName: nil, dueText: nil, isOverdue: false),
        ]
        let focusMs = 2 * 3_600_000.0 + 15 * 60_000
        return FokusEntry(
            date: now,
            focus: .init(
                focusMs: focusMs, isRunning: false,
                goal: DailyGoalCalc.progress(focusMs: focusMs, goalMinutes: 210), timerStart: nil),
            tasks: .init(items: items, done: 1, total: 3), isAvailable: true)
    }
}

/// İki widget'ın ortak zaman çizelgesi sağlayıcısı: veri App Group deposundan okunur, hesaplar `FokusDomain`'dedir.
/// Yapılandırma gerektirmediği için `StaticConfiguration` (AppIntent çözümlemesine bağlı değil).
struct FokusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FokusEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (FokusEntry) -> Void) {
        if context.isPreview {
            completion(.sample())
            return
        }
        Task { @MainActor in completion(Self.entries(at: [.now]).first ?? .unavailable) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<FokusEntry>) -> Void) {
        Task { @MainActor in
            let plan = WidgetCalc.timelinePlan(isRunning: Self.isRunning(), now: .now)
            let entries = Self.entries(at: plan.entries)
            completion(
                Timeline(entries: entries.isEmpty ? [.unavailable] : entries, policy: .after(plan.reloadAfter)))
        }
    }

    @MainActor
    private static func isRunning() -> Bool {
        (try? FokusSystem.snapshot().focus.isRunning) ?? false
    }

    @MainActor
    static func entries(at dates: [Date]) -> [FokusEntry] {
        dates.compactMap { date in
            guard let snapshot = try? FokusSystem.snapshot(now: date) else { return nil }
            return FokusEntry(date: date, focus: snapshot.focus, tasks: snapshot.tasks, isAvailable: true)
        }
    }
}

// MARK: - Bugünkü odak + hedef halkası

struct FocusGoalWidget: Widget {
    static let kind = "FokusFocusGoal"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FokusTimelineProvider()) { entry in
            FocusGoalView(entry: entry)
                .containerBackground(.fkBackground, for: .widget)
        }
        .configurationDisplayName("Bugünkü odak")
        .description("Bugünkü odak süren ve günlük hedef halkan.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

/// Süre metni: akarken sistemin saydığı sayaç (`Text(timerInterval:)`), değilse "2 sa 15 dk".
struct FocusTotalText: View {
    let focus: WidgetCalc.FocusSummary
    var style: FokusTextStyle = .numeralLG

    var body: some View {
        Group {
            if let start = focus.timerStart {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    ForEach(Array(FocusFormat.durationParts(focus.focusMs).enumerated()), id: \.offset) { _, part in
                        Text("\(part.value)")
                        Text(part.unit).font(.caption2).foregroundStyle(.fkSecondaryLabel)
                    }
                }
            }
        }
        .fokusTextStyle(style)
        .foregroundStyle(.fkLabel)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

struct FocusGoalView: View {
    let entry: FokusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: available { medium }
        default: available { small }
        }
    }

    @ViewBuilder private func available<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if entry.isAvailable {
            content()
        } else {
            Text("Fokus'u bir kez aç").fokusTextStyle(.footnote)
                .foregroundStyle(.fkSecondaryLabel).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var ratio: Double { entry.focus.ratio }

    // MARK: Ana ekran

    private var small: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text("Bugün").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            Spacer(minLength: 0)
            ring(size: 76, lineWidth: 7).frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            footer
        }
    }

    private var medium: some View {
        HStack(spacing: FokusSpacing.xl) {
            ring(size: 104, lineWidth: 9)
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("Bugün").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                FocusTotalText(focus: entry.focus, style: .numeralLG)
                footer
                Spacer(minLength: 0)
                if let next = entry.tasks.next {
                    HStack(spacing: FokusSpacing.xs) {
                        Image(systemName: "circle").font(.caption2)
                        Text(next.title).lineLimit(1)
                    }
                    .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.fkSeparator, lineWidth: lineWidth)
            Circle().trim(from: 0, to: ratio)
                .stroke(
                    entry.focus.goal?.isReached == true ? FokusColor(.success) : FokusColor(.accentInk),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            if entry.focus.goal == nil || family == .systemSmall {
                FocusTotalText(focus: entry.focus, style: family == .systemSmall ? .numeralSM : .numeral)
                    .padding(lineWidth + 4)
            } else {
                Text("\(Int((ratio * 100).rounded()))%")
                    .fokusTextStyle(.numeralSM).foregroundStyle(.fkLabel)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var footer: some View {
        if let goal = entry.focus.goal {
            Text(goal.isReached ? "Hedef tamam" : DailyGoalCalc.remainingText(goal))
                .fokusTextStyle(.footnote)
                .foregroundStyle(goal.isReached ? FokusColor(.success) : FokusColor(.secondaryLabel))
        } else {
            Text(entry.focus.isRunning ? "Odak sürüyor" : "Hedef yok")
                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
        }
    }

    // MARK: Kilit ekranı

    private var circular: some View {
        Gauge(value: ratio) {
            Image(systemName: "timer")
        } currentValueLabel: {
            Text(entry.focus.goal != nil ? "\(Int((ratio * 100).rounded()))" : "\(Int(entry.focus.focusMs / 60_000))")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "timer").widgetAccentable()
                if let start = entry.focus.timerStart {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
                } else {
                    Text(FocusFormat.durationText(entry.focus.focusMs)).monospacedDigit()
                }
            }
            .font(.headline)
            if let goal = entry.focus.goal {
                Gauge(value: goal.ratio) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity).widgetAccentable()
            }
            Text(entry.tasks.next?.title ?? (entry.tasks.isComplete ? "Görevler tamam" : "Görev yok"))
                .font(.caption).lineLimit(1)
        }
    }

    private var inline: some View {
        let total = FocusFormat.durationText(entry.focus.focusMs)
        let text = entry.focus.goal.map { "\(total) · \(DailyGoalCalc.remainingText($0))" } ?? total
        return Label(text, systemImage: "timer")
    }
}
