import FokusDesign
import FokusDomain
import SwiftUI

/// Tek ekran: boştayken "Başlat" (ders seçmeden hemen başlar); oturum sürerken büyük sayaç ("son devamdan
/// beri", `FocusActivityCalc.State.timerStart` — telefondaki tam ekran odakla aynı değer), "Mola"/"Devam"
/// ve "Bitir". Telefonda başlatılan oturum da burada görünür ve buradan yönetilir (kayıt eşlemesi).
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
        .containerBackground(.fkBackground, for: .navigation)
    }
}

private struct IdleView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Odak").watchEyebrow()
            if let last = model.lastFinished {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Son oturum").font(.caption2).foregroundStyle(.fkSecondaryLabel)
                    Text(FocusFormat.durationText(last.focusMs))
                        .font(WatchFont.numeral(30)).foregroundStyle(.fkLabel)
                        .minimumScaleFactor(0.6).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button("Başlat") { model.start() }
                .buttonStyle(WatchPrimaryButtonStyle())
                .accessibilityIdentifier("watch.start")
            if model.actionFailed {
                Text("Başlatılamadı").font(.caption2).foregroundStyle(.fkDanger)
            }
        }
        .padding(.horizontal, 4)
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
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button(isFocus ? "Mola" : "Devam") { model.togglePause() }
                    .buttonStyle(WatchPrimaryButtonStyle())
                    .accessibilityIdentifier("watch.togglePause")
                Button("Bitir") { confirmFinish = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("watch.finish")
            }
        }
        .confirmationDialog("Oturum bitirilsin mi?", isPresented: $confirmFinish) {
            Button("Bitir", role: .destructive) { model.finish() }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}
