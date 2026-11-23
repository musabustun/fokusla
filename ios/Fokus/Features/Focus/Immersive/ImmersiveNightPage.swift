import FokusDesign
import FokusDomain
import SwiftUI

/// OLED gece görünümü: saf siyah zemin, yalnızca soluk süre (+ çok soluk faz etiketi). Tasarım kuralının
/// belgelenmiş istisnası: `Color.black` (OLED'de piksel tamamen kapalı olsun). İçerik koyu şemada çözülür.
/// Gece kırmızısı etkinse üst katmandaki `standByNightTint` rengi kırmızıya çevirir.
struct ImmersiveNightPage: View {
    let context: ImmersivePageContext

    private static let digitOpacity: Double = 0.38

    var body: some View {
        let snap = context.snapshot
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: FokusSpacing.md) {
                ZStack {
                    StandByDigits(text: FocusFormat.clock(snap.primaryMs), style: context.clockStyle)
                        .foregroundStyle(context.digitColor.opacity(Self.digitOpacity))
                }
                .frame(maxHeight: .infinity)
                .immersiveClockAccessibility(phase: snap.phase, ms: snap.primaryMs)
                ImmersivePhaseLabel(phase: snap.phase, isDimmed: true)
            }
            .padding(context.contentPadding)
        }
        .environment(\.colorScheme, .dark)
        .immersivePageContainer(.night)
    }
}
