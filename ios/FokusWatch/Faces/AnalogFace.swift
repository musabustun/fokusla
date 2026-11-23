import FokusDesign
import FokusDomain
import SwiftUI

/// Analog kadran: 60 dakikalık kronometre kadranı. Dakika ibresi oturumun (son devamdan beri) dakikasını,
/// ince ibre saniyeyi gösterir; her tam saat ortadaki rozette sayılır. Always On'da saniye ibresi gizlenir
/// ve dakikada bir çizilir. Açılar `WatchFaceCalc`'ten.
struct AnalogFace: View {
    let live: FocusLink.LiveState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var state: FocusActivityCalc.State { live.state }

    var body: some View {
        VStack(spacing: 2) {
            FaceHeader(live: live)
            TimelineView(.animation(minimumInterval: isLuminanceReduced ? 60 : 1, paused: false)) { context in
                let elapsed = WatchFaceCalc.elapsed(state, now: context.date)
                Dial(
                    elapsed: elapsed, isFocus: state.phase == .focus, showsSeconds: !isLuminanceReduced,
                    isDimmed: isLuminanceReduced)
            }
            .accessibilityElement()
            .accessibilityLabel(state.phase == .focus ? "Odak süresi" : "Mola süresi")
            .accessibilityValue(Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false))
        }
    }
}

private struct Dial: View {
    let elapsed: TimeInterval
    let isFocus: Bool
    let showsSeconds: Bool
    let isDimmed: Bool

    private var hand: FokusColor { isFocus ? FokusColor(.accent) : FokusColor(.success) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<60, id: \.self) { tick in
                    let major = tick % 5 == 0
                    Capsule()
                        .fill(major ? FokusColor(.label) : FokusColor(.tertiaryLabel))
                        .frame(width: major ? 2.5 : 1, height: major ? size * 0.07 : size * 0.035)
                        .offset(y: -size / 2 + (major ? size * 0.05 : size * 0.035))
                        .rotationEffect(.degrees(Double(tick) * 6))
                }
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    let angle = Double(minute) * 6 * .pi / 180
                    let radius = size * 0.33
                    Text("\(minute == 0 ? 60 : minute)")
                        .font(WatchFont.numeral(size * 0.09))
                        .foregroundStyle(.fkSecondaryLabel)
                        .offset(x: radius * sin(angle), y: -radius * cos(angle))
                }
                // Dolmakta olan dakikalar: ibrenin arkasında ince yay.
                Circle()
                    .trim(from: 0, to: WatchFaceCalc.minuteHandDegrees(elapsed: elapsed) / 360)
                    .stroke(hand.opacity(isDimmed ? 0.25 : 0.35), style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.14)
                Capsule()
                    .fill(hand)
                    .frame(width: 4, height: size * 0.36)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(WatchFaceCalc.minuteHandDegrees(elapsed: elapsed)))
                if showsSeconds {
                    Capsule()
                        .fill(FokusColor(.label))
                        .frame(width: 1.2, height: size * 0.44)
                        .offset(y: -size * 0.2)
                        .rotationEffect(.degrees(WatchFaceCalc.secondHandDegrees(elapsed: elapsed)))
                }
                Circle().fill(FokusColor(.label)).frame(width: 7, height: 7)
                let hours = WatchFaceCalc.completedHours(elapsed: elapsed)
                if hours > 0 {
                    Text("+\(hours) sa")
                        .font(WatchFont.numeral(size * 0.09))
                        .foregroundStyle(hand)
                        .offset(y: size * 0.2)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isDimmed ? 0.7 : 1)
        }
    }
}
