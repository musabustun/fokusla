import FokusDesign
import FokusDomain
import SwiftUI

/// Günlük hedef halkası: içinde bugünkü toplam, altında "Hedef 4 sa · kalan 1 sa 20 dk".
/// Hedef yoksa saatlik tur halkası + oturum süresi + "Hedef koymak için Ayarlar" ipucu.
struct ImmersiveRingPage: View {
    let context: ImmersivePageContext

    private static let ringLineWidth: CGFloat = 10
    private static let digitsWidthRatio: CGFloat = 0.66
    private static let digitsHeightRatio: CGFloat = 0.3

    var body: some View {
        let snap = context.snapshot
        let goal = DailyGoalCalc.progress(focusMs: snap.todayTotalMs, goalMinutes: context.dailyGoalMinutes)
        GeometryReader { proxy in
            let size = proxy.size
            let isWide = !context.isCompactColumn && size.width > size.height * 1.15
            let diameter = isWide ? min(size.height, size.width * 0.45) : min(size.width, size.height * 0.62)
            Group {
                if isWide {
                    HStack(spacing: FokusSpacing.xxl) {
                        ring(snap, goal: goal, diameter: diameter)
                        info(snap, goal: goal, alignment: .leading)
                    }
                } else {
                    VStack(spacing: FokusSpacing.xl) {
                        ring(snap, goal: goal, diameter: diameter)
                        info(snap, goal: goal, alignment: .center)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.ring)
    }

    @ViewBuilder
    private func ring(_ snap: ImmersiveSnapshot, goal: DailyGoalCalc.Progress?, diameter: CGFloat) -> some View {
        if let goal {
            ProgressRing(progress: goal.ratio, lineWidth: Self.ringLineWidth, tone: snap.phase == .break ? .success : .accent) {
                StandByDigits(text: FocusFormat.clock(snap.todayTotalMs), style: context.clockStyle)
                    .foregroundStyle(context.digitColor)
                    .frame(width: diameter * Self.digitsWidthRatio, height: diameter * Self.digitsHeightRatio)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bugün toplam")
            .accessibilityValue(
                "\(FocusFormat.durationText(snap.todayTotalMs)), \(DailyGoalCalc.remainingText(goal))")
            .accessibilityIdentifier("immersive.todayTotal")
        } else {
            ProgressRing(progress: snap.hourLap, lineWidth: Self.ringLineWidth, tone: snap.phase == .break ? .success : .accent) {
                StandByDigits(text: FocusFormat.clock(snap.primaryMs), style: context.clockStyle)
                    .foregroundStyle(context.digitColor)
                    .frame(width: diameter * Self.digitsWidthRatio, height: diameter * Self.digitsHeightRatio)
            }
            .frame(width: diameter, height: diameter)
            .immersiveClockAccessibility(phase: snap.phase, ms: snap.primaryMs)
        }
    }

    private func info(_ snap: ImmersiveSnapshot, goal: DailyGoalCalc.Progress?, alignment: HorizontalAlignment)
        -> some View
    {
        VStack(alignment: alignment, spacing: FokusSpacing.md) {
            ImmersivePhaseLabel(phase: snap.phase)
            if let goal {
                Text("Hedef \(DailyGoalCalc.goalText(minutes: goal.goalMinutes)) · \(DailyGoalCalc.remainingText(goal))")
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
                    .accessibilityHidden(true)
                Text(FocusFormat.clock(snap.primaryMs))
                    .fokusTextStyle(.numeralLG)
                    .foregroundStyle(context.digitColor)
                    .immersiveClockAccessibility(phase: snap.phase, ms: snap.primaryMs)
            } else {
                VStack(alignment: alignment, spacing: FokusSpacing.xs) {
                    Text("Bugün toplam").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    FocusDurationValue(ms: snap.todayTotalMs, style: .numeralLG)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Bugün toplam")
                .accessibilityValue(FocusFormat.durationText(snap.todayTotalMs))
                .accessibilityIdentifier("immersive.todayTotal")
                Text("Hedef koymak için Ayarlar")
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkSecondaryLabel)
            }
        }
    }
}
