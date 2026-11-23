import FokusDesign
import FokusDomain
import SwiftUI

/// Her kadranın altındaki kontroller: ana eylem Mola/Devam (kehribar hap), yanında Bitir (onaylı).
/// Always On'da (bilek indirildi) gizlenir; kadran kısık kalır.
struct FaceControls: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let isFocus: Bool
    @State private var confirmFinish = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.togglePause()
            } label: {
                Label(isFocus ? "Mola" : "Devam", systemImage: isFocus ? "pause.fill" : "play.fill")
            }
            .buttonStyle(WatchPrimaryButtonStyle())
            .accessibilityIdentifier("watch.togglePause")

            Button {
                confirmFinish = true
            } label: {
                Image(systemName: "stop.fill").accessibilityLabel("Bitir")
            }
            .buttonStyle(WatchRoundButtonStyle())
            .accessibilityIdentifier("watch.finish")
        }
        .opacity(isLuminanceReduced ? 0 : 1)
        .allowsHitTesting(!isLuminanceReduced)
        .confirmationDialog("Oturum bitirilsin mi?", isPresented: $confirmFinish) {
            Button("Bitir", role: .destructive) { model.finish() }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}

/// Kadranların ortak başlığı: ODAK/MOLA ve (varsa) ders adı.
struct FaceHeader: View {
    let live: FocusLink.LiveState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var isFocus: Bool { live.state.phase == .focus }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isFocus ? FokusColor(.accent) : FokusColor(.success))
                .frame(width: 6, height: 6)
            Text(isFocus ? "Odak" : "Mola").fokusTextStyle(.eyebrow)
                .foregroundStyle(isFocus ? FokusColor(.accentInk) : FokusColor(.success))
            if let subject = live.subjectName {
                Text(subject).font(.caption2).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
            }
        }
        .opacity(isLuminanceReduced ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}
