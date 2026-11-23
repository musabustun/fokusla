import FokusDesign
import FokusDomain
import SwiftUI

/// Bugün sayfası: günlük toplam + hedef halkası ve bugünün görevleri (işaretlenebilir).
struct TodayPage: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = model.snapshot {
                    FocusRing(focus: snapshot.focus)
                    tasks(snapshot.tasks)
                } else {
                    Text("Veri hazırlanıyor").font(.footnote).foregroundStyle(.fkSecondaryLabel)
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.fkBackground, for: .tabView)
    }

    @ViewBuilder private func tasks(_ list: WidgetCalc.TaskList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.total == 0 ? "Görevler" : "Görevler · \(list.done)/\(list.total)").watchEyebrow()
            if list.items.isEmpty {
                Text("Bugün görev yok").font(.footnote).foregroundStyle(.fkSecondaryLabel)
            }
            ForEach(list.items.prefix(8)) { item in
                TaskRow(item: item) { model.toggleTask(item.id) }
            }
        }
    }
}

/// Günlük hedef halkası: ortada bugünkü toplam (odak sürerken sistem sayar), altında kalan süre.
private struct FocusRing: View {
    let focus: WidgetCalc.FocusSummary

    var body: some View {
        HStack(spacing: 12) {
            ProgressRing(progress: focus.ratio, lineWidth: 7, tone: focus.goal?.isReached == true ? .success : .accent)
                .frame(width: 64, height: 64)
                .accessibilityLabel("Günlük hedef")
            VStack(alignment: .leading, spacing: 2) {
                Text("Bugün").watchEyebrow()
                total
                Text(caption).font(.caption2).foregroundStyle(.fkSecondaryLabel).lineLimit(2)
            }
        }
    }

    @ViewBuilder private var total: some View {
        Group {
            if let start = focus.timerStart {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
            } else {
                Text(FocusFormat.durationText(focus.focusMs))
            }
        }
        .font(WatchFont.numeral(22)).foregroundStyle(.fkLabel)
        .minimumScaleFactor(0.6).lineLimit(1)
    }

    private var caption: String {
        if let goal = focus.goal { return DailyGoalCalc.remainingText(goal) }
        return focus.isRunning ? "Odak sürüyor" : "Hedef yok"
    }
}

private struct TaskRow: View {
    let item: WidgetCalc.TaskItem
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                ZStack {
                    if item.isDone {
                        Circle().fill(.fkSuccess)
                    } else {
                        Circle().stroke(.fkSeparatorStrong, lineWidth: 1.5)
                    }
                }
                .frame(width: 20, height: 20)
                .overlay { if item.isDone { Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.black) } }
                Text(item.title)
                    .font(.footnote)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .fkSecondaryLabel : .fkLabel)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.canToggle)
        .accessibilityValue(item.isDone ? "Tamamlandı" : "Açık")
    }
}
