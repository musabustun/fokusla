import SwiftUI

/// İlerleme halkası (web `ProgressRing`): ince `separator` izi, `accentInk` (veya `success`) yay.
public struct ProgressRing<Label: View>: View {
    public enum Tone: Sendable { case accent, success }

    private let progress: Double
    private let lineWidth: CGFloat
    private let tone: Tone
    private let label: Label

    /// - Parameter progress: 0…1 (dışı kırpılır).
    public init(
        progress: Double, lineWidth: CGFloat = 6, tone: Tone = .accent,
        @ViewBuilder label: () -> Label
    ) {
        self.progress = min(max(progress, 0), 1)
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
            label
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("%\(Int((progress * 100).rounded()))"))
    }
}

extension ProgressRing where Label == EmptyView {
    public init(progress: Double, lineWidth: CGFloat = 6, tone: Tone = .accent) {
        self.init(progress: progress, lineWidth: lineWidth, tone: tone) { EmptyView() }
    }
}
