import FokusDesign
import FokusDomain
import SwiftUI

/// Odak ekranı. Oturum yokken Başlat + istatistikler (`StatsView`); sürerken yatay kaydırılan üç kadran (dijital, analog, halka) ve
/// ekrana dokununca beliren Mola/Devam + Bitir. Seçilen kadran `fokus.watch.face`'te kalır. Telefonda başlatılan oturum da
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
                StatsView()
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

/// Süren oturum: yatay kaydırılan üç kadran. Mola/Devam + Bitir ekrana dokununca belirir ve birkaç saniye
/// sonra gizlenir (kadran tüm ekranı kullanır); VoiceOver açıkken hep görünür, Always On'da hiç görünmez.
/// Bitir onayı burada durur ki kontroller gizlenince onay penceresi kapanmasın.
private struct RunningView: View {
    let live: FocusLink.LiveState
    @Environment(WatchModel.self) private var model
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverOn
    @AppStorage("fokus.watch.face") private var faceRaw = WatchFaceCalc.Face.digital.rawValue
    /// Açılışta bir kez görünür (nerede olduklarını göstermek için), sonra gizlenir.
    @State private var showsControls = true
    @State private var hideRequest = 0
    @State private var confirmFinish = false

    private static let controlsVisibleFor: Duration = .seconds(4)

    private var selection: Binding<WatchFaceCalc.Face> {
        Binding(get: { WatchFaceCalc.face(from: faceRaw) }, set: { faceRaw = $0.rawValue })
    }

    private var controlsVisible: Bool { (showsControls || isVoiceOverOn) && !isLuminanceReduced }

    var body: some View {
        TabView(selection: selection) {
            page(.digital) { DigitalFace(live: live) }
            page(.analog) { AnalogFace(live: live) }
            page(.ring) { RingFace(live: live) }
        }
        .tabViewStyle(.page)
        .overlay(alignment: .bottom) {
            if controlsVisible {
                FaceControls(
                    isFocus: live.state.phase == .focus,
                    onTogglePause: {
                        model.togglePause()
                        revealControls()
                    },
                    onFinish: { confirmFinish = true }
                )
                .padding(.horizontal, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .accessibilityAction(named: "Kontrolleri göster") { revealControls() }
        .task(id: hideRequest) { await hideControlsLater() }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced { showsControls = false }
        }
        .onChange(of: confirmFinish) { _, isConfirming in
            if !isConfirming { hideRequest += 1 }
        }
        .confirmationDialog("Oturum bitirilsin mi?", isPresented: $confirmFinish) {
            Button("Bitir", role: .destructive) { model.finish() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private func page<Face: View>(_ face: WatchFaceCalc.Face, @ViewBuilder content: () -> Face) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
            .containerBackground(.fkBackground, for: .tabView)
            .tag(face)
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) { showsControls.toggle() }
        if showsControls { hideRequest += 1 }
    }

    private func revealControls() {
        withAnimation(.easeOut(duration: 0.2)) { showsControls = true }
        hideRequest += 1
    }

    private func hideControlsLater() async {
        guard showsControls else { return }
        try? await Task.sleep(for: Self.controlsVisibleFor)
        guard !Task.isCancelled, !confirmFinish else { return }
        withAnimation(.easeIn(duration: 0.25)) { showsControls = false }
    }
}
