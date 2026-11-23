import FokusDesign
import FokusDomain
import SwiftUI

/// Odak ekranı. Oturum yokken "Başlat"; sürerken yatay kaydırılan üç kadran (dijital, analog, halka) ve
/// altta Mola/Devam + Bitir. Seçilen kadran `fokus.watch.face`'te kalır. Telefonda başlatılan oturum da
/// burada görünür ve buradan yönetilir (kayıt eşlemesi). Odak sürerken uygulama kadranda kalır
/// (`WatchRuntimeSession`); bilek inince Always On kısık görünüm gösterir.
struct FocusPage: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var runtime = WatchRuntimeSession()

    var body: some View {
        Group {
            if let live = model.live {
                RunningView(live: live)
            } else {
                IdleView()
                    .containerBackground(.fkBackground, for: .navigation)
            }
        }
        .onChange(of: model.live?.sessionId, initial: true) { updateRuntime() }
        .onChange(of: scenePhase) { updateRuntime() }
    }

    private func updateRuntime() {
        runtime.update(isFocusRunning: model.live != nil, isActive: scenePhase == .active)
    }
}

private struct RunningView: View {
    let live: FocusLink.LiveState
    @AppStorage("fokus.watch.face") private var faceRaw = WatchFaceCalc.Face.digital.rawValue

    private var selection: Binding<WatchFaceCalc.Face> {
        Binding(get: { WatchFaceCalc.face(from: faceRaw) }, set: { faceRaw = $0.rawValue })
    }

    var body: some View {
        TabView(selection: selection) {
            page(.digital) { DigitalFace(live: live) }
            page(.analog) { AnalogFace(live: live) }
            page(.ring) { RingFace(live: live) }
        }
        .tabViewStyle(.page)
    }

    private func page<Face: View>(_ face: WatchFaceCalc.Face, @ViewBuilder content: () -> Face) -> some View {
        VStack(spacing: 6) {
            content().frame(maxHeight: .infinity)
            FaceControls(isFocus: live.state.phase == .focus)
        }
        .padding(.horizontal, 2)
        .containerBackground(.fkBackground, for: .tabView)
        .tag(face)
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
            Button {
                model.start()
            } label: {
                Label("Başlat", systemImage: "play.fill")
            }
            .buttonStyle(WatchPrimaryButtonStyle())
            .accessibilityIdentifier("watch.start")
            if model.actionFailed {
                Text("Başlatılamadı").font(.caption2).foregroundStyle(.fkDanger)
            }
        }
        .padding(.horizontal, 4)
    }
}
