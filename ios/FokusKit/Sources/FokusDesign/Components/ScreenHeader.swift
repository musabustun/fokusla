import SwiftUI

/// Ekran başlığı (web `ScreenHeader`): eyebrow + Bricolage büyük başlık + opsiyonel alt metin ve
/// sağda eylem. Geniş (iPad) genişlikte başlık `display` boyutuna çıkar.
public struct ScreenHeader<Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(
        _ title: String, eyebrow: String? = nil, subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                if let eyebrow {
                    Text(eyebrow).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                }
                Text(title)
                    .fokusTextStyle(horizontalSizeClass == .regular ? .display : .largeTitle)
                    .foregroundStyle(.fkLabel)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
            }
            Spacer(minLength: FokusSpacing.md)
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    public init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil) {
        self.init(title, eyebrow: eyebrow, subtitle: subtitle) { EmptyView() }
    }
}

#Preview("ScreenHeader — koyu") {
    FokusPreviewCanvas(.dark) {
        ScreenHeader("Bugün", eyebrow: "19 Kasım", subtitle: "YKS'ye 214 gün") {
            Button("Tümü") {}.buttonStyle(.fokusPlain)
        }
    }
}

#Preview("ScreenHeader — açık") {
    FokusPreviewCanvas(.light) { ScreenHeader("Odak", eyebrow: "Kronometre") }
}
