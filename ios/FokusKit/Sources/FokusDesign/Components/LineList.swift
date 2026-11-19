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
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkSecondaryLabel)
            }
        }
    }
}

/// Satır sonundaki ">" işareti (yalnızca görsel; `tertiaryLabel`).
public struct LineChevron: View {
    private let isVisible: Bool

    public init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.fkTertiaryLabel)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true)
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
                    Text(title).fokusTextStyle(.body).foregroundStyle(.fkLabel)
                    if let subtitle {
                        Text(subtitle).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
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

extension LineRow where Accessory == LineChevron {
    /// Gezinme satırı: sağda ">" gösterir (`showsChevron: true`). `NavigationLink`/`Button`
    /// içinde `.buttonStyle(.fokusRow)` ile kullan.
    public init(_ title: String, subtitle: String? = nil, value: String? = nil, showsChevron: Bool) {
        self.init(title, subtitle: subtitle, value: value) {
            LineChevron(isVisible: showsChevron)
        }
    }
}

/// Satır içeren `Button`/`NavigationLink` için: basılıyken `fill` zemin, nötr metin rengi.
public struct FokusRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { Rectangle().fill(.fkFill).opacity(configuration.isPressed ? 1 : 0) }
            .animation(FokusMotion.baseAnimation, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FokusRowButtonStyle {
    public static var fokusRow: FokusRowButtonStyle { FokusRowButtonStyle() }
}

#Preview("LineSection — koyu") {
    FokusPreviewCanvas(.dark) { LineListPreviewContent() }
}

#Preview("LineSection — açık") {
    FokusPreviewCanvas(.light) { LineListPreviewContent() }
}

private struct LineListPreviewContent: View {
    var body: some View {
        LineSection("Bugün", footer: "Süreler zaman damgalarından hesaplanır.") {
            LineRow("Matematik", subtitle: "TYT", value: "1:20")
            LineRow("Fizik", value: "0:45")
            LineRow("Kitaplar", showsChevron: true)
        }
    }
}
