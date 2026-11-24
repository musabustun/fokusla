import FokusDesign
import FokusDomain
import SwiftUI

/// Dijital kadran: büyük mono sayaç (son devamdan / mola başından beri), altında bugünkü toplam.
/// Uyanıkken sayaçları sistem sayar (`Text(timerInterval:)`). Always On'da (bilek inik) sistem ekranı en çok
/// dakikada bir günceller: o zaman dakikalık metin `TimelineView(.periodic…)` ile çizilir (canlı sayaç
/// orada donar).
struct DigitalFace: View {
    let live: FocusLink.LiveState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var state: FocusActivityCalc.State { live.state }
    private var isFocus: Bool { state.phase == .focus }

    var body: some View {
        VStack(spacing: 4) {
            FaceHeader(live: live)
            Group {
                if isLuminanceReduced {
                    TimelineView(.periodic(from: state.timerStart, by: 60)) { context in
                        Text(WatchFaceCalc.minuteText(elapsed: WatchFaceCalc.elapsed(state, now: context.date)))
                            .foregroundStyle(FokusColor(.secondaryLabel))
                    }
                } else {
                    Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                        .foregroundStyle(FokusColor(.label))
                }
            }
            .font(WatchFont.numeral(54))
            .minimumScaleFactor(0.4).lineLimit(1)
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
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if let start = state.dayFocusStart {
            HStack(spacing: 4) {
                Text("Bugün").foregroundStyle(.fkSecondaryLabel)
                Group {
                    if isLuminanceReduced {
                        TimelineView(.periodic(from: start, by: 60)) { context in
                            Text(WatchFaceCalc.dayMinuteText(state, now: context.date) ?? "")
                        }
                    } else if state.phase == .focus {
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
