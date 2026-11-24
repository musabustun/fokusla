import FokusDesign
import FokusDomain
import SwiftUI

/// Kadranın üstünde (dokununca) beliren kontroller: ana eylem Mola/Devam (kehribar hap), yanında Bitir.
/// Görünürlük ve Bitir onayı `RunningView`'dadır (kontroller gizlenince onay penceresi kapanmasın).
struct FaceControls: View {
    let isFocus: Bool
    let onTogglePause: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTogglePause) {
                Label(isFocus ? "Mola" : "Devam", systemImage: isFocus ? "pause.fill" : "play.fill")
            }
            .buttonStyle(WatchPrimaryButtonStyle())
            .accessibilityIdentifier("watch.togglePause")

            Button(action: onFinish) {
                Image(systemName: "stop.fill").accessibilityLabel("Bitir")
            }
            .buttonStyle(WatchRoundButtonStyle())
            .accessibilityIdentifier("watch.finish")
        }
        .padding(4)
        .background(Capsule().fill(.fkBackground.opacity(0.85)))
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
