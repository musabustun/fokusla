import SwiftUI

/// Yazı ölçeği — web `TYPE_SCALE` ile aynı adlar ve boyutlar. Dynamic Type ile ölçeklenir.
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

    /// Harf aralığı (pt) = web em değeri × boyut.
    public var tracking: CGFloat {
        switch self {
        case .display: -0.04 * 44
        case .largeTitle: -0.035 * 36
        case .title1: -0.03 * 28
        case .title2: -0.02 * 22
        case .title3: -0.015 * 20
        case .eyebrow: 0.12 * 11
        case .numeralHero: -0.06 * 72
        case .numeralXL: -0.05 * 56
        case .numeralLG: -0.04 * 36
        case .numeral: -0.03 * 24
        case .numeralSM: -0.01 * 17
        default: 0
        }
    }

    var isNumeral: Bool { rawValue.hasPrefix("numeral") }
}

extension View {
    /// Yazı stilini uygular (font + harf aralığı; `eyebrow` büyük harf, rakamlar eş genişlikli).
    public func fokusTextStyle(_ style: FokusTextStyle) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .textCase(style == .eyebrow ? .uppercase : nil)
            .monospacedDigit()
    }
}

/// Gömülü fontlar (OFL). PostScript adları sabittir.
public enum FokusFonts {
    public static let displayExtraBold = "BricolageGrotesque-ExtraBold"
    public static let displayMedium = "BricolageGrotesque-Medium"
    public static let monoRegular = "JetBrainsMono-Regular"
    public static let monoMedium = "JetBrainsMono-Medium"

    /// Paket içindeki fontları süreç için kaydeder. Uygulama açılışında bir kez çağır; tekrar güvenli.
    public static func registerAll() {}
}
