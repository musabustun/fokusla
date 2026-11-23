import SwiftUI

/// Verilen alana sığacak şekilde ölçeklenen büyük sayaç rakamları (tam ekran odak).
///
/// Titremez: her karakter sabit genişlikli bir hücreye yerleşir (rakamlar tek hücre genişliğini paylaşır,
/// `:` ve diğer ayraçlar daha dar hücre alır). Hücre ve punto hesabı saf fonksiyonlardır
/// (`fontSize`, `cellWidths`), testlerde doğrulanır. Renk çağıranın `foregroundStyle`'ından gelir;
/// erişilebilirlik etiketini çağıran verir (görünüm VoiceOver'dan gizlidir).
public struct StandByDigits: View {
    private let text: String
    private let style: StandByClockStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: String, style: StandByClockStyle) {
        self.text = text
        self.style = style
    }

    /// Stil başına ölçüler (em): rakam ilerlemesi, ayraç ilerlemesi, harf aralığı.
    public struct Metrics: Equatable, Sendable {
        public let digitAdvanceEm: CGFloat
        public let separatorAdvanceEm: CGFloat
        public let trackingEm: CGFloat
    }

    /// Satır kutusu yüksekliği (em): glifler kutudan küçüktür, yalnızca hafif pay bırakır.
    nonisolated static let lineBoxEm: CGFloat = 1.15
    nonisolated static let fitMargin: CGFloat = 0.96
    public nonisolated static let sizeRange: ClosedRange<CGFloat> = 12...640

    public nonisolated static func metrics(for style: StandByClockStyle) -> Metrics {
        switch style {
        case .mono: Metrics(digitAdvanceEm: 0.6, separatorAdvanceEm: 0.36, trackingEm: -0.02)
        case .grotesk: Metrics(digitAdvanceEm: 0.64, separatorAdvanceEm: 0.32, trackingEm: -0.02)
        case .rounded: Metrics(digitAdvanceEm: 0.62, separatorAdvanceEm: 0.30, trackingEm: -0.01)
        case .thin: Metrics(digitAdvanceEm: 0.58, separatorAdvanceEm: 0.28, trackingEm: -0.01)
        case .condensed: Metrics(digitAdvanceEm: 0.5, separatorAdvanceEm: 0.26, trackingEm: -0.01)
        }
    }

    /// Her karakterin hücre genişliği, punto birimiyle (em). Rakam → rakam hücresi, diğerleri → ayraç hücresi.
    public nonisolated static func cellWidths(text: String, style: StandByClockStyle) -> [CGFloat] {
        let metrics = metrics(for: style)
        return text.map { character in
            let advance = character.isNumber ? metrics.digitAdvanceEm : metrics.separatorAdvanceEm
            return advance + metrics.trackingEm
        }
    }

    /// Alana sığan en büyük punto (saf).
    public nonisolated static func fontSize(text: String, style: StandByClockStyle, in size: CGSize) -> CGFloat {
        let totalEm = max(cellWidths(text: text, style: style).reduce(0, +), 0.1)
        let byWidth = size.width / totalEm
        let byHeight = size.height / lineBoxEm
        let fitted = min(byWidth, byHeight) * fitMargin
        guard fitted.isFinite else { return sizeRange.lowerBound }
        return min(max(fitted, sizeRange.lowerBound), sizeRange.upperBound)
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = Self.fontSize(text: text, style: style, in: proxy.size)
            let widths = Self.cellWidths(text: text, style: style)
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    cell(character, width: widths[index] * size, size: size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func cell(_ character: Character, width: CGFloat, size: CGFloat) -> some View {
        Text(String(character))
            .font(style.font(size: size))
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .lineLimit(1)
            .fixedSize()
            .frame(width: width)
    }
}
