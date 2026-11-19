import SwiftUI

/// İlerleme halkası (web `ProgressRing`): ince `separator` izi, `accentInk` (veya `success`) yay.
/// Değer değişince yay 700ms akar; hareket azaltmada anında. Boyut çerçeveden gelir
/// (`.frame(width:)` veya `.aspectRatio`).
public struct ProgressRing<Label: View>: View {
    public enum Tone: Sendable { case accent, success }

    private let progress: Double
    private let lineWidth: CGFloat
    private let tone: Tone
    private let label: Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter progress: 0…1 (dışı kırpılır).
    public init(
        progress: Double, lineWidth: CGFloat = 6, tone: Tone = .accent,
        @ViewBuilder label: () -> Label
    ) {
        self.progress = progress.isNaN ? 0 : min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.tone = tone
        self.label = label()
    }

    public var body: some View {
        ZStack {
            Circle().stroke(.fkSeparator, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tone == .success ? FokusColor(.success) : FokusColor(.accentInk),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : FokusMotion.progressAnimation, value: progress)
            label
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("%\(Int((progress * 100).rounded()))"))
    }
}

extension ProgressRing where Label == EmptyView {
    public init(progress: Double, lineWidth: CGFloat = 6, tone: Tone = .accent) {
        self.init(progress: progress, lineWidth: lineWidth, tone: tone) { EmptyView() }
    }
}

#Preview("ProgressRing — koyu") {
    FokusPreviewCanvas(.dark) { RingPreviewContent() }
}

#Preview("ProgressRing — açık") {
    FokusPreviewCanvas(.light) { RingPreviewContent() }
}

private struct RingPreviewContent: View {
    var body: some View {
        HStack(spacing: FokusSpacing.xl) {
            ProgressRing(progress: 0.65) {
                Text("65").fokusTextStyle(.numeral).foregroundStyle(.fkLabel)
            }
            .frame(width: 120, height: 120)
            ProgressRing(progress: 1, tone: .success).frame(width: 64, height: 64)
        }
    }
}
