import AppIntents
import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

/// Bugünün görevleri (medium/large). Satırdaki daire `ToggleTaskIntent` ile görevi widget'tan tamamlar/geri alır.
struct TasksWidget: Widget {
    static let kind = "FokusTasks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FokusTimelineProvider()) { entry in
            TasksView(entry: entry)
                .containerBackground(.fkBackground, for: .widget)
        }
        .configurationDisplayName("Bugünkü görevler")
        .description("Bugünün görevlerini widget'tan işaretle.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TasksView: View {
    let entry: FokusEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int { family == .systemLarge ? 7 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            header
            if !entry.isAvailable {
                message("Fokus'u bir kez aç")
            } else if entry.tasks.total == 0 {
                message("Bugün için görev yok")
            } else {
                ForEach(entry.tasks.items.prefix(limit)) { item in row(item) }
                let hidden = entry.tasks.items.count - limit
                if hidden > 0 {
                    Text("+\(hidden) görev daha").fokusTextStyle(.footnote).foregroundStyle(.fkTertiaryLabel)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Görevler").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            Spacer()
            Text("\(entry.tasks.done)/\(entry.tasks.total)")
                .fokusTextStyle(.numeralSM)
                .foregroundStyle(entry.tasks.isComplete ? FokusColor(.success) : FokusColor(.label))
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detail(_ item: WidgetCalc.TaskItem) -> String {
        [item.subjectName, item.dueText].compactMap { $0 }.joined(separator: " · ")
    }

    private func row(_ item: WidgetCalc.TaskItem) -> some View {
        HStack(spacing: FokusSpacing.md) {
            Button(intent: ToggleTaskIntent(taskId: item.id)) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? FokusColor(.success) : FokusColor(.accentInk))
                    .widgetAccentable(!item.isDone)
            }
            .buttonStyle(.plain)
            .disabled(!item.canToggle)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .fokusTextStyle(.callout)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? FokusColor(.tertiaryLabel) : FokusColor(.label))
                    .lineLimit(1)
                if !item.isDone, !detail(item).isEmpty {
                    Text(detail(item)).fokusTextStyle(.caption)
                        .foregroundStyle(item.isOverdue ? FokusColor(.danger) : FokusColor(.secondaryLabel))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
