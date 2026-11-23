import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

/// "Odak saati": masada saat gibi duran widget (StandBy için; ana ekranda da small). Büyük saat, tarih ve bugünkü
/// toplam odak. Saat dakika başı girdilerle ilerler; veri okuma tek seferdir (girdiler aynı özeti paylaşır).
struct FocusClockWidget: Widget {
    static let kind = "FokusFocusClock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FocusClockProvider()) { entry in
            FocusClockEntryView(entry: entry)
                .containerBackground(.fkBackground, for: .widget)
        }
        .configurationDisplayName("Odak saati")
        .description("Büyük saat ve bugünkü odak süren. StandBy için ideal.")
        .supportedFamilies([.systemSmall])
    }
}

struct FocusClockEntryView: View {
    let entry: FokusEntry

    var body: some View {
        if entry.isAvailable {
            FocusClockView(
                date: entry.date, display: WidgetCalc.standBy(focus: entry.focus, subject: entry.activeSubject))
        } else {
            Text("Fokus'u bir kez aç").fokusTextStyle(.footnote)
                .foregroundStyle(.fkSecondaryLabel).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FocusClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> FokusEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (FokusEntry) -> Void) {
        if context.isPreview {
            completion(.sample())
            return
        }
        Task { @MainActor in completion(FokusTimelineProvider.entries(at: [.now]).first ?? .unavailable) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<FokusEntry>) -> Void) {
        Task { @MainActor in
            let plan = WidgetCalc.clockTimelinePlan(now: .now)
            // Tek okuma: tüm dakika girdileri aynı özeti taşır (sayaç `Text(timerInterval:)` ile sistemce sayılır).
            let base = FokusTimelineProvider.entries(at: [.now]).first ?? .unavailable
            let entries = plan.entries.map { date -> FokusEntry in var entry = base; entry.date = date; return entry }
            completion(Timeline(entries: entries, policy: .after(plan.reloadAfter)))
        }
    }
}
