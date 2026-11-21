import SwiftUI

/// Yatay ilerleme çubuğu (web `ProgressBar`): `separator` iz, `accentInk` (veya `success`) dolgu.
/// Değer değişince 700ms akar; hareket azaltmada anında. Yükseklik boyuta göre sabit
/// (`.small` 2pt liste satırı, `.medium` 4pt detay); genişlik üst görünümden gelir.
///
/// `label` verilirse VoiceOver "ad, %46" okur; verilmezse çubuk dekoratiftir ve değer
/// başka yerde metin olarak verilmelidir.
public struct ProgressBar: View {
    public enum Tone: Sendable { case accent, success }
    public enum Size: Sendable { case small, medium }

    private let progress: Double
    private let label: String?
    private let tone: Tone
    private let size: Size

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter value: 0…1 (dışı ve NaN kırpılır).
    public init(value: Double, label: String? = nil, tone: Tone = .accent, size: Size = .medium) {
        self.progress = value.isNaN ? 0 : min(max(value, 0), 1)
        self.label = label
        self.tone = tone
        self.size = size
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.fkSeparator)
                Capsule()
                    .fill(tone == .success ? FokusColor(.success) : FokusColor(.accentInk))
                    .frame(width: proxy.size.width * progress)
                    .animation(reduceMotion ? nil : FokusMotion.progressAnimation, value: progress)
            }
        }
        .frame(height: size == .small ? 2 : 4)
        .modifier(ProgressBarAccessibility(label: label, progress: progress))
    }
}

private struct ProgressBarAccessibility: ViewModifier {
    let label: String?
    let progress: Double

    func body(content: Content) -> some View {
        if let label {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(Text("%\(Int((progress * 100).rounded()))"))
        } else {
            content.accessibilityHidden(true)
        }
    }
}

#Preview("ProgressBar — koyu") {
    FokusPreviewCanvas(.dark) { ProgressBarPreviewContent() }
}

#Preview("ProgressBar — açık") {
    FokusPreviewCanvas(.light) { ProgressBarPreviewContent() }
}

private struct ProgressBarPreviewContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            ProgressBar(value: 0.46, label: "Kitap ilerlemesi")
            ProgressBar(value: 1, label: "Tamamlandı", tone: .success)
            ProgressBar(value: 0.2, size: .small)
            ProgressBar(value: 0, size: .small)
        }
    }
}
