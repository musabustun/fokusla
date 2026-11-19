import SwiftUI

/// Büyük rakam + küçük etiket (web `Metric`): ekranların ana öğesi. Etiket önce okunur.
public struct Metric: View {
    public enum Size: Sendable { case hero, xl, lg, md, sm }
    public enum Tone: Sendable { case `default`, accent, success }

    private let label: String
    private let value: String
    private let unit: String?
    private let caption: String?
    private let size: Size
    private let tone: Tone
    private let isNumeric: Bool

    /// - Parameters:
    ///   - isNumeric: `false` ise (tarih/metin değeri) mono yerine Bricolage ve bir kademe küçük.
    ///   - tone: `accent` yalnızca ekranın ana sayısı içindir.
    public init(
        label: String, value: String, unit: String? = nil, caption: String? = nil,
        size: Size = .lg, tone: Tone = .default, isNumeric: Bool = true
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.caption = caption
        self.size = size
        self.tone = tone
        self.isNumeric = isNumeric
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .fokusTextStyle(valueStyle)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit {
                    Text(unit).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
            }
            if let caption {
                Text(caption).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var valueStyle: FokusTextStyle {
        switch (size, isNumeric) {
        case (.hero, true): .numeralHero
        case (.xl, true): .numeralXL
        case (.lg, true): .numeralLG
        case (.md, true): .numeral
        case (.sm, true): .numeralSM
        case (.hero, false), (.xl, false): .title1
        case (.lg, false): .title2
        case (.md, false): .title3
        case (.sm, false): .headline
        }
    }

    private var valueColor: FokusColor {
        switch tone {
        case .default: .fkLabel
        case .accent: .fkAccentInk
        case .success: .fkSuccess
        }
    }
}

#Preview("Metric — koyu") {
    FokusPreviewCanvas(.dark) { MetricPreviewContent() }
}

#Preview("Metric — açık") {
    FokusPreviewCanvas(.light) { MetricPreviewContent() }
}

private struct MetricPreviewContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            Metric(label: "Bugün", value: "2:45", unit: "sa", caption: "Dünden 20 dk fazla", size: .hero, tone: .accent)
            HStack(spacing: FokusSpacing.xxl) {
                Metric(label: "Ortalama mola", value: "8", unit: "dk")
                Metric(label: "Son test", value: "19 Kasım", size: .md, isNumeric: false)
            }
        }
    }
}
