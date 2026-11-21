import FokusDesign
import FokusDomain
import SwiftUI

/// Görev satırı (iOS liste satırı görünümü): onay kutusu + ayrıntı düğmesi. Web `TaskRow`.
struct TaskRowView: View {
    let model: TaskViews.RowModel
    var isSelected = false
    let onToggle: () -> Void
    let onSelect: () -> Void

    private var title: String { model.task.title }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                checkButton
                Button(action: onSelect) {
                    HStack(spacing: FokusSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .fokusTextStyle(.body)
                                .foregroundStyle(model.isDone ? FokusColor(.secondaryLabel) : FokusColor(.label))
                                .strikethrough(model.isDone)
                                .multilineTextAlignment(.leading)
                            if let subtitle {
                                subtitle.fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: FokusSpacing.sm)
                        LineChevron()
                    }
                    .frame(minHeight: fokusMinTapTarget)
                    .padding(.vertical, FokusSpacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.fokusRow)
                .accessibilityLabel("Ayrıntılar: \(title)")
                .accessibilityIdentifier("task.open.\(title)")
            }
            .background { if isSelected { Rectangle().fill(.fkFill) } }
            .overlay(alignment: .leading) {
                if isSelected { Rectangle().fill(.fkAccent).frame(width: 2) }
            }
            Divider().overlay(.fkSeparator)
        }
    }

    private var checkButton: some View {
        Button(action: onToggle) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canToggle)
        .opacity(model.canToggle ? 1 : 0.4)
        .accessibilityLabel(title)
        .accessibilityValue(model.isDone ? "Tamamlandı" : "Tamamlanmadı")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("task.check.\(title)")
    }

    /// "Yarın · Her gün · Fizik · 42/50 soru · 3 gün seri": gecikme `danger`, seri `warning` ikonlu.
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
        if let recurrence = model.recurrence { parts.append(Text(recurrence)) }
        if let subject = model.subjectName { parts.append(Text(subject)) }
        if let quantity = model.quantity { parts.append(Text(quantity).monospacedDigit()) }
        if let streak = model.streak {
            parts.append(
                Text("\(Text(Image(systemName: "flame.fill")).foregroundStyle(.fkWarning)) \(TaskFormatting.streakText(streak))"))
        }
        if let rate = model.rate { parts.append(Text(rate)) }
        guard var result = parts.first else { return nil }
        for part in parts.dropFirst() { result = Text("\(result) · \(part)") }
        return result
    }
}
