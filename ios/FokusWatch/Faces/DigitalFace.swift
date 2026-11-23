import FokusDesign
import FokusDomain
import SwiftUI

/// Dijital kadran: büyük mono sayaç (son devamdan / mola başından beri), altında bugünkü toplam.
/// Sayaçları sistem sayar (`Text(timerInterval:)`): saniyelik yeniden çizim yok, Always On'da da verimli.
struct DigitalFace: View {
    let live: FocusLink.LiveState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var state: FocusActivityCalc.State { live.state }
    private var isFocus: Bool { state.phase == .focus }

    var body: some View {
        VStack(spacing: 4) {
            FaceHeader(live: live)
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                .font(WatchFont.numeral(54))
                .foregroundStyle(isLuminanceReduced ? FokusColor(.secondaryLabel) : FokusColor(.label))
                .minimumScaleFactor(0.5).lineLimit(1)
                .multilineTextAlignment(.center)
                .accessibilityLabel(isFocus ? "Odak süresi" : "Mola süresi")
            DayTotalLine(state: state)
        }
        .frame(maxWidth: .infinity)
    }
}

/// "Bugün 1:42:10" satırı (hedef açıkken; molada durur).
struct DayTotalLine: View {
    let state: FocusActivityCalc.State

    var body: some View {
        if let start = state.dayFocusStart {
            HStack(spacing: 4) {
                Text("Bugün").foregroundStyle(.fkSecondaryLabel)
                Group {
                    if state.phase == .focus {
                        Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    } else {
                        Text(FocusFormat.durationText(state.timerStart.timeIntervalSince(start) * 1000))
                    }
                }
                .foregroundStyle(.fkLabel)
            }
            .font(WatchFont.numeral(13))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
