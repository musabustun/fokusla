import SwiftUI

/// Yazı ölçeği — web `TYPE_SCALE` ile aynı adlar ve boyutlar. Dynamic Type ile ölçeklenir.
/// Başlıklar Bricolage Grotesque, rakamlar/eyebrow JetBrains Mono, gövde sistem fontu.
public enum FokusTextStyle: String, CaseIterable, Sendable {
    case display, largeTitle, title1, title2, title3
    case headline, body, callout, subheadline, footnote, caption
    case eyebrow
    case numeralHero, numeralXL, numeralLG, numeral, numeralSM

    /// SwiftUI fontu (gömülü fontlar `FokusFonts.registerAll()` ile kaydedilmiş olmalı).
    public var font: Font {
        switch self {
        case .display: .custom(FokusFonts.displayExtraBold, size: 44, relativeTo: .largeTitle)
        case .largeTitle: .custom(FokusFonts.displayExtraBold, size: 36, relativeTo: .largeTitle)
        case .title1: .custom(FokusFonts.displayExtraBold, size: 28, relativeTo: .title)
        case .title2: .custom(FokusFonts.displayMedium, size: 22, relativeTo: .title2)
        case .title3: .custom(FokusFonts.displayMedium, size: 20, relativeTo: .title3)
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption
        case .eyebrow: .custom(FokusFonts.monoMedium, size: 11, relativeTo: .caption2)
        case .numeralHero: .custom(FokusFonts.monoRegular, size: 72, relativeTo: .largeTitle)
        case .numeralXL: .custom(FokusFonts.monoRegular, size: 56, relativeTo: .largeTitle)
        case .numeralLG: .custom(FokusFonts.monoRegular, size: 36, relativeTo: .title)
        case .numeral: .custom(FokusFonts.monoRegular, size: 24, relativeTo: .title2)
        case .numeralSM: .custom(FokusFonts.monoMedium, size: 17, relativeTo: .body)
        }
    }

    /// Web `TYPE_SCALE.size` ile aynı punto boyutu (Dynamic Type öncesi taban boyut).
    public var size: CGFloat {
        switch self {
        case .display: 44
        case .largeTitle: 36
        case .title1: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .eyebrow: 11
        case .numeralHero: 72
        case .numeralXL: 56
        case .numeralLG: 36
        case .numeral: 24
        case .numeralSM: 17
        }
    }

    /// Web `TYPE_SCALE.lineHeight` (pt). SwiftUI satır yüksekliğini fonttan türetir; bu değer
    /// referans/test içindir.
    public var lineHeight: CGFloat {
        switch self {
        case .display: 48
        case .largeTitle: 40
        case .title1: 32
        case .title2: 28
        case .title3: 24
        case .headline: 22
        case .body: 24
        case .callout: 22
        case .subheadline: 20
        case .footnote: 18
        case .caption: 16
        case .eyebrow: 16
        case .numeralHero: 72
        case .numeralXL: 56
        case .numeralLG: 40
        case .numeral: 30
        case .numeralSM: 22
        }
    }

    /// Harf aralığı (em; web `TYPE_SCALE.tracking`).
    public var trackingEm: CGFloat {
        switch self {
        case .display: -0.04
        case .largeTitle: -0.035
        case .title1: -0.03
        case .title2: -0.02
        case .title3: -0.015
        case .eyebrow: 0.12
        case .numeralHero: -0.06
        case .numeralXL: -0.05
        case .numeralLG: -0.04
        case .numeral: -0.03
        case .numeralSM: -0.01
        default: 0
        }
    }

    /// Harf aralığı (pt) = web em değeri × boyut.
    public var tracking: CGFloat { trackingEm * size }

    /// Rakam stili mi? (eş genişlikli rakamlar yalnızca bunlarda açılır.)
    var isNumeral: Bool { rawValue.hasPrefix("numeral") }
}

extension View {
    /// Yazı stilini uygular: font + harf aralığı; `eyebrow` büyük harf, rakam stilleri eş genişlikli.
    public func fokusTextStyle(_ style: FokusTextStyle) -> some View {
        self
            .font(style.isNumeral ? style.font.monospacedDigit() : style.font)
            .tracking(style.tracking)
            .textCase(style == .eyebrow ? .uppercase : nil)
    }
}
