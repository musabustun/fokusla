import FokusDesign
import FokusDomain
import SwiftUI

/// StandBy ikili görünümü: analog saat + tarih, küçük odak sayacı ve faz. Yatayda yan yana, dikeyde alt alta.
struct ImmersiveClockPage: View {
    let context: ImmersivePageContext

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let turkish = Locale(identifier: "tr_TR")

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isWide = size.width > size.height * 1.15
            let side = isWide ? min(size.height, size.width * 0.48) : min(size.width, size.height * 0.52)
            Group {
                if isWide {
                    HStack(spacing: FokusSpacing.xxl) {
                        clock(side)
                        info(alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: FokusSpacing.xl) {
                        clock(side)
                        info(alignment: .center)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.clock)
    }

    private func clock(_ side: CGFloat) -> some View {
        StandByAnalogClock(date: context.now, showsSecondHand: !reduceMotion)
            .frame(width: side, height: side)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Saat")
            .accessibilityValue(Text(context.now, format: .dateTime.hour().minute().locale(Self.turkish)))
    }

    private func info(alignment: HorizontalAlignment) -> some View {
        let snap = context.snapshot
        return VStack(alignment: alignment, spacing: FokusSpacing.md) {
            Text(context.now, format: .dateTime.weekday(.wide).locale(Self.turkish))
                .fokusTextStyle(.title2)
                .foregroundStyle(.fkLabel)
            Text(context.now, format: .dateTime.day().month(.wide).locale(Self.turkish))
                .fokusTextStyle(.title1)
                .foregroundStyle(.fkLabel)
            StandByDigits(text: FocusFormat.clock(snap.primaryMs), style: context.clockStyle)
                .foregroundStyle(context.digitColor)
                .frame(maxWidth: 320, minHeight: 44, maxHeight: 64)
                .immersiveClockAccessibility(phase: snap.phase, ms: snap.primaryMs)
            ImmersivePhaseLabel(phase: snap.phase)
            ImmersiveSecondaryLine(secondary: snap.secondary)
        }
    }
}
