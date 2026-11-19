import SwiftUI

/// Çizgili liste bölümü (web `ListSection`): üstte eyebrow başlık, satırlar arasında 1px çizgi,
/// kart/gölge yok.
public struct LineSection<Content: View>: View {
    private let title: String?
    private let footer: String?
    private let content: Content

    public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            if let title {
                Text(title)
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                content
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.fkSecondaryLabel)
            }
        }
    }
}

/// Çizgili liste satırı (web `ListRow`): başlık, opsiyonel alt başlık, sağda değer/aksesuar,
/// altta 1px çizgi. En az 44pt yükseklik.
public struct LineRow<Accessory: View>: View {
    private let title: String
    private let subtitle: String?
    private let value: String?
    private let accessory: Accessory

    public init(
        _ title: String, subtitle: String? = nil, value: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(.fkLabel)
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(.fkSecondaryLabel)
                    }
                }
                Spacer(minLength: FokusSpacing.sm)
                if let value {
                    Text(value).fokusTextStyle(.numeralSM).foregroundStyle(.fkSecondaryLabel)
                }
                accessory
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.md)
            Divider().overlay(.fkSeparator)
        }
        .contentShape(Rectangle())
    }
}

extension LineRow where Accessory == EmptyView {
    public init(_ title: String, subtitle: String? = nil, value: String? = nil) {
        self.init(title, subtitle: subtitle, value: value) { EmptyView() }
    }
}
