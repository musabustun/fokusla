import FokusDesign
import FokusDomain
import SwiftUI

/// Zamanlayıcı (halka) kadranı: günlük hedef açıksa halka bugünkü toplamın hedefe oranıdır; kapalıysa
/// geçerli saatin dolan kısmı. Ortada sayaç ve halkanın anlamı. İlerleme `WatchFaceCalc.ringProgress`.
struct RingFace: View {
    let live: FocusLink.LiveState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var state: FocusActivityCalc.State { live.state }
    private var isFocus: Bool { state.phase == .focus }

    var body: some View {
        VStack(spacing: 2) {
            FaceHeader(live: live)
            TimelineView(.animation(minimumInterval: isLuminanceReduced ? 60 : 1, paused: false)) { context in
                let progress = WatchFaceCalc.ringProgress(state, now: context.date)
                ProgressRing(progress: progress, lineWidth: 10, tone: isFocus ? .accent : .success) {
                    VStack(spacing: 0) {
                        Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
                            .font(WatchFont.numeral(26))
                            .foregroundStyle(isLuminanceReduced ? FokusColor(.secondaryLabel) : FokusColor(.label))
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text(caption(progress: progress))
                            .font(.caption2).foregroundStyle(.fkSecondaryLabel)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(4)
                .opacity(isLuminanceReduced ? 0.75 : 1)
            }
        }
    }

    private func caption(progress: Double) -> String {
        guard isFocus else { return "mola" }
        guard state.goalMinutes != nil, state.dayFocusStart != nil else { return "bu saat" }
        let percent = Int((progress * 100).rounded())
        return progress >= 1 ? "hedef ✓" : "hedef %\(percent)"
    }
}
