import FokusDesign
import FokusDomain
import SwiftUI

/// Bugünkü görevler: rutinler + son tarihi yaklaşan/geçen ödevler; dokunarak tamamla / geri al.
/// Web `TasksCard`. Yazma `TodayScreen`'dedir (Görevler deposundaki `toggleCompletion`).
struct TodayTasksSection: View {
    let overview: TodayCalc.TaskOverview
    let context: TaskViews.Context
    let errorMessage: String?
    let onToggle: (UUID) -> Void

    /// Listede en fazla bu kadar görev gösterilir; fazlası Görevler'de.
    private static let visibleLimit = 8

    private var visibleItems: [TodayCalc.TaskItem] { Array(overview.items.prefix(Self.visibleLimit)) }
    private var hiddenCount: Int { overview.items.count - visibleItems.count }

    var body: some View {
        TodaySection("Görevler", identifier: "today.tasks") {
            if overview.totalCount > 0 {
                Text("\(overview.doneCount)/\(overview.totalCount)")
                    .fokusTextStyle(.numeralSM)
                    .foregroundStyle(overview.isComplete ? FokusColor(.success) : FokusColor(.secondaryLabel))
                    .accessibilityLabel("\(overview.totalCount) görevin \(overview.doneCount) tanesi tamamlandı")
                    .accessibilityIdentifier("today.tasks.progress")
            }
        } content: {
            if let errorMessage {
                Text(errorMessage).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                    .padding(.vertical, FokusSpacing.md)
                    .accessibilityIdentifier("today.tasks.error")
            }
            if overview.items.isEmpty {
                empty
            } else {
                if overview.isComplete { allDoneBanner }
                ForEach(visibleItems) { item in
                    TodayTaskRow(
                        model: TaskViews.row(item.task, context: context), group: item.group,
                        onToggle: { onToggle(item.id) })
                }
                if hiddenCount > 0 { moreLink }
            }
        }
    }

    private var allDoneBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.sm) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.fkSuccess).accessibilityHidden(true)
                Text("Bugünkü görevlerin tamam. Eline sağlık.")
                    .fokusTextStyle(.subheadline).foregroundStyle(.fkSuccess)
                Spacer(minLength: 0)
            }
            .padding(.vertical, FokusSpacing.md)
            Divider().overlay(.fkSeparator)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.tasks.allDone")
    }

    private var moreLink: some View {
        TodaySectionLink(section: .tasks) {
            LineRow("Tümünü gör", value: "+\(hiddenCount)", showsChevron: true)
        }
        .buttonStyle(.fokusRow)
        .accessibilityIdentifier("today.tasks.more")
    }

    private var empty: some View {
        EmptyStateView(
            "Bugün için görev yok", systemImage: "checklist",
            message: "Rutinlerini ve ödevlerini ekle; günün planı burada görünsün."
        ) {
            TodaySectionLink(section: .tasks) { Text("Görev ekle") }
                .buttonStyle(.fokusSecondary)
                .fixedSize()
                .accessibilityIdentifier("today.tasks.add")
        }
        .accessibilityIdentifier("today.tasks.empty")
    }
}

/// Görev satırı: onay dairesi + başlık/alt metin; satırın tamamı tek dokunuşla tamamlar / geri alır.
struct TodayTaskRow: View {
    let model: TaskViews.RowModel
    let group: TodayCalc.TaskGroup
    let onToggle: () -> Void

    private var title: String { model.task.title }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: FokusSpacing.xs) {
                    check
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .fokusTextStyle(.body)
                            .foregroundStyle(model.isDone ? FokusColor(.secondaryLabel) : FokusColor(.label))
                            .strikethrough(model.isDone)
                            .multilineTextAlignment(.leading)
                        if let subtitle { subtitle.fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel) }
                    }
                    Spacer(minLength: FokusSpacing.sm)
                }
                .frame(minHeight: fokusMinTapTarget)
                .padding(.vertical, FokusSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.fokusRow)
            .disabled(!model.canToggle)
            .opacity(model.canToggle ? 1 : 0.4)
            .accessibilityLabel(title)
            .accessibilityValue(model.isDone ? "Tamamlandı" : "Tamamlanmadı")
            .accessibilityHint(model.isDone ? "Geri almak için çift dokun" : "Tamamlamak için çift dokun")
            .accessibilityIdentifier("today.task.\(title)")
            Divider().overlay(.fkSeparator)
        }
    }

    private var check: some View {
        ZStack {
            if model.isDone {
                Circle().fill(.fkSuccess)
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(FokusColor(.successContrast))
            } else {
                Circle().strokeBorder(.fkSeparatorStrong, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
        .accessibilityHidden(true)
    }

    /// "Gecikti · Fizik · 42/50 soru · 3 gün seri": gecikme `danger`, seri `warning` ikonlu.
    private var subtitle: Text? {
        var parts: [Text] = []
        if let due = model.due {
            if due.isOverdue {
                parts.append(
                    Text("\(Text(Image(systemName: "exclamationmark.circle.fill"))) \(due.text)")
                        .foregroundStyle(.fkDanger))
            } else {
                parts.append(Text(due.text))
            }
        }
        if let subject = model.subjectName { parts.append(Text(subject)) }
        if let quantity = model.quantity { parts.append(Text(quantity).monospacedDigit()) }
        if let streak = model.streak {
            parts.append(
                Text("\(Text(Image(systemName: "flame.fill")).foregroundStyle(.fkWarning)) \(TaskFormatting.streakText(streak))"))
        }
        guard var result = parts.first else { return nil }
        for part in parts.dropFirst() { result = Text("\(result) · \(part)") }
        return result
    }
}
