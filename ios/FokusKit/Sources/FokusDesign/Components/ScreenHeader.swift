import SwiftUI

/// Ekran başlığı (web `ScreenHeader`): eyebrow + Bricolage büyük başlık + opsiyonel alt metin ve
/// sağda eylem.
public struct ScreenHeader<Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                if let eyebrow {
                    Text(eyebrow).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                }
                Text(title)
                    .fokusTextStyle(.largeTitle)
                    .foregroundStyle(.fkLabel)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.fkSecondaryLabel)
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
