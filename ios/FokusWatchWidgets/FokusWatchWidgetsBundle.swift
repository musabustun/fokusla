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

/// Sade komplikasyon: odak sürmüyorsa "Odak başlat" (dokununca saat uygulaması açılır), sürüyorsa sistemin
/// saydığı sayaç. Hedef halkası/görev YOK. `timerStart`: ana sayacın sıfır anı (son devamdan beri; molada
/// mola başlangıcı) — telefondaki tam ekran odakla aynı değer.
struct ComplicationEntry: TimelineEntry {
    var date: Date
    var timerStart: Date?
    var isBreak: Bool

    var isActive: Bool { timerStart != nil }

    static func sample(now: Date = .now) -> ComplicationEntry {
        ComplicationEntry(date: now, timerStart: now.addingTimeInterval(-754), isBreak: false)
    }
}

/// Veri App Group deposundan okunur (uzantı depoyu CloudKit'siz açar); saat uygulaması her değişiklikten
/// sonra `reloadAllTimelines` çağırdığı için tek girdi yeterlidir — sayacı sistem sayar.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ComplicationEntry) -> Void) {
        if context.isPreview {
            completion(.sample())
            return
        }
        Task { @MainActor in completion(Self.entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ComplicationEntry>) -> Void) {
        Task { @MainActor in completion(Timeline(entries: [Self.entry()], policy: .never)) }
    }

    @MainActor
    static func entry(now: Date = .now) -> ComplicationEntry {
        guard let state = (try? FokusSystem.snapshot(now: now))?.activity else {
            return ComplicationEntry(date: now, timerStart: nil, isBreak: false)
        }
        return ComplicationEntry(date: now, timerStart: state.timerStart, isBreak: state.phase == .break)
    }
}

struct FocusComplication: Widget {
    static let kind = "FokusWatchFocus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.fkBackground, for: .widget)
        }
        .configurationDisplayName("Odak")
        .description("Odak başlatmak için dokun; sürerken sayacı gösterir.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct ComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryInline: inline
        default: rectangular
        }
    }

    @ViewBuilder private var counter: some View {
        if let start = entry.timerStart {
            Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isActive {
                counter.font(.caption2).minimumScaleFactor(0.6).lineLimit(1).padding(4)
            } else {
                Image(systemName: "play.fill").widgetAccentable()
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(entry.isBreak ? "Mola" : "Odak", systemImage: "timer")
                .font(.caption).widgetAccentable()
            if entry.isActive {
                counter.font(.title2)
            } else {
                Text("Odak başlat").font(.headline)
            }
        }
    }

    private var corner: some View {
        Image(systemName: entry.isActive ? "timer" : "play.fill")
            .widgetAccentable()
            .widgetLabel {
                if let start = entry.timerStart {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
                } else {
                    Text("Odak başlat")
                }
            }
    }

    private var inline: some View {
        Group {
            if let start = entry.timerStart {
                Label {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
                } icon: {
                    Image(systemName: "timer")
                }
            } else {
                Label("Odak başlat", systemImage: "play.fill")
            }
        }
    }
}
