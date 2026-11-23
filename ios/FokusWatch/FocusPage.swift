import FokusDesign
import FokusDomain
import SwiftUI

/// Odak sayfası: boştayken ders seçimi (opsiyonel) + Başlat; oturum sürerken büyük sayaç ("son devamdan
/// beri", `FocusActivityCalc.State.timerStart` — telefondaki tam ekran odakla aynı değer), moladan
/// dönüldüyse oturum toplamı, Duraklat/Devam ve Bitir.
struct FocusPage: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        Group {
            if let live = model.live {
                RunningView(live: live)
            } else {
                IdleView()
            }
        }
        .containerBackground(.fkBackground, for: .tabView)
    }
}

private struct IdleView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Odak").watchEyebrow()
            summary
            Spacer(minLength: 0)
            NavigationLink {
                SubjectPickerView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ders").watchEyebrow()
                        Text(model.selectedSubjectName ?? "Seçilmedi")
                            .font(.footnote).foregroundStyle(.fkLabel).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.fkTertiaryLabel)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("watch.subject")
            Button("Başlat") { Task { await model.start() } }
                .buttonStyle(WatchPrimaryButtonStyle())
                .accessibilityIdentifier("watch.start")
            if model.actionFailed {
                Text("Başlatılamadı").font(.caption2).foregroundStyle(.fkDanger)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var summary: some View {
        if let last = model.lastFinished {
            VStack(alignment: .leading, spacing: 2) {
                Text("Son oturum").font(.caption2).foregroundStyle(.fkSecondaryLabel)
                Text(FocusFormat.durationText(last.focusMs))
                    .font(WatchFont.numeral(28)).foregroundStyle(.fkLabel)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
        } else if let focus = model.snapshot?.focus {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bugün").font(.caption2).foregroundStyle(.fkSecondaryLabel)
                Text(FocusFormat.durationText(focus.focusMs))
                    .font(WatchFont.numeral(28)).foregroundStyle(.fkLabel)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
        }
    }
}

private struct RunningView: View {
    @Environment(WatchModel.self) private var model
    let live: FocusLink.LiveState
    @State private var confirmFinish = false

    private var state: FocusActivityCalc.State { live.state }
    private var isFocus: Bool { state.phase == .focus }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Text(isFocus ? "Odak" : "Mola").fokusTextStyle(.eyebrow)
                    .foregroundStyle(isFocus ? FokusColor(.accentInk) : FokusColor(.success))
                if let subject = live.subjectName {
                    Text(subject).font(.caption2).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
                }
            }
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                .font(WatchFont.numeral(44)).foregroundStyle(.fkLabel)
                .minimumScaleFactor(0.5).lineLimit(1)
                .accessibilityLabel(isFocus ? "Odak süresi" : "Mola süresi")
            total
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                Button {
                    Task { await model.togglePause() }
                } label: {
                    Image(systemName: isFocus ? "pause.fill" : "play.fill")
                }
                .buttonStyle(WatchCircleButtonStyle(filled: true))
                .accessibilityLabel(isFocus ? "Duraklat" : "Devam et")
                .accessibilityIdentifier("watch.pause")
                Button {
                    confirmFinish = true
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(WatchCircleButtonStyle())
                .accessibilityLabel("Bitir")
                .accessibilityIdentifier("watch.finish")
            }
        }
        .confirmationDialog("Oturum bitirilsin mi?", isPresented: $confirmFinish) {
            Button("Bitir", role: .destructive) { Task { await model.finish() } }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    /// Oturum toplamı yalnızca ana sayaçtan farklıysa (moladan dönüş ya da molada) gösterilir —
    /// Live Activity'deki kuralla aynı; molada toplam `pauseTime` ile donar.
    @ViewBuilder private var total: some View {
        if let start = state.sessionFocusStart, state.hasResumedAfterBreak || !isFocus {
            HStack(spacing: 4) {
                Text("Toplam").watchEyebrow()
                Text(
                    timerInterval: start...Date.distantFuture, pauseTime: isFocus ? nil : state.timerStart,
                    countsDown: false
                )
                .font(WatchFont.numeral(15)).foregroundStyle(.fkSecondaryLabel)
            }
        }
    }
}
