import FokusDesign
import FokusDomain
import SwiftUI

/// Bugün bölümü: eyebrow başlık (+ isteğe bağlı sağ eylem) ve 1px çizgi; kart yok.
struct TodaySection<Trailing: View, Content: View>: View {
    private let title: String
    private let identifier: String
    private let trailing: Trailing
    private let content: Content

    init(
        _ title: String, identifier: String, @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.identifier = identifier
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: FokusSpacing.sm)
                trailing
            }
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                content
            }
        }
        // `.contain`: kapsayıcı kendi kimliğini alır, çocukların kimliklerini ezmez.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

extension TodaySection where Trailing == EmptyView {
    init(_ title: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.init(title, identifier: identifier, trailing: { EmptyView() }, content: content)
    }
}

/// Başka bir bölüme geçiş. iPhone'da tab bar'da olmayan bölümler (Kitaplar, Sosyal) sekme olarak
/// seçilemez; onlar için `NavigationLink(value:)`, diğerleri için paylaşılan gezinme durumu kullanılır.
struct TodaySectionLink<Label: View>: View {
    let section: AppSection
    @ViewBuilder let label: Label

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        if horizontalSizeClass == .compact && !section.inTabBar {
            NavigationLink(value: section) { label }
        } else {
            Button { navigation.open(section) } label: { label }
        }
    }
}

/// Bölüm başlığının sağındaki küçük metin eylemi (≥44pt dokunma alanı).
struct TodayLinkLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .fokusTextStyle(.footnote)
            .foregroundStyle(.fkSecondaryLabel)
            .frame(minHeight: fokusMinTapTarget)
            .contentShape(Rectangle())
    }
}

/// "1 sa 5 dk" → büyük mono rakamlar + küçük, ikincil birimler.
struct TodayDuration: View {
    let ms: Double
    let style: FokusTextStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.xs) {
            ForEach(Array(Self.parts(ms).enumerated()), id: \.offset) { _, part in
                Text("\(part.value)").fokusTextStyle(style).foregroundStyle(.fkLabel)
                Text(part.unit)
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                    .padding(.trailing, FokusSpacing.xs)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// Süre parçaları; hiç odak yokken "0 sn" yerine "0 dk" (günlük toplam dakika birimiyle okunur).
    static func parts(_ ms: Double) -> [FocusFormat.DurationPart] {
        ms > 0 ? FocusFormat.durationParts(ms) : [FocusFormat.DurationPart(value: 0, unit: "dk")]
    }

    /// `parts` ile aynı biçimde metin ("2 sa 40 dk", "0 dk").
    static func text(_ ms: Double) -> String {
        parts(ms).map { "\($0.value) \($0.unit)" }.joined(separator: " ")
    }
}
