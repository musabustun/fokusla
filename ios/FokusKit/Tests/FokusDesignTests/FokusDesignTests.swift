import SwiftUI
import Testing

@testable import FokusDesign

#if canImport(UIKit)
import UIKit
#endif

/// Web `tokens.ts` `COLORS` tablosunun kopyası (kaynak). Palet eklenince buraya da eklenir.
private let webColors: [FokusPalette: [String: [String: String]]] = [
    .kahve: [
        "light": [
            "Background": "#F5F2EA", "Surface": "#FBF9F4", "SurfaceElevated": "#FFFDF8",
            "Fill": "#E8E3D7", "ControlThumb": "#1B1A16", "SwitchThumbOff": "#77736A",
            "Label": "#1B1A16", "SecondaryLabel": "#5C5950", "TertiaryLabel": "#7A766C",
            "Separator": "#DCD6C9", "SeparatorStrong": "#8C877B",
            "Accent": "#FFB547", "AccentContrast": "#1A1205", "AccentInk": "#955500",
            "AccentSubtle": "#F8E5C0", "Success": "#2D6A43", "SuccessContrast": "#FFFFFF",
            "Warning": "#955500", "Danger": "#B3261E", "DangerSubtle": "#F7E1DC",
            "Scrim": "#1B1A1666",
        ],
        "dark": [
            "Background": "#0E0F0C", "Surface": "#141511", "SurfaceElevated": "#1A1B17",
            "Fill": "#22231E", "ControlThumb": "#EDEAE2", "SwitchThumbOff": "#8A877F",
            "Label": "#EDEAE2", "SecondaryLabel": "#9A978E", "TertiaryLabel": "#6F6C64",
            "Separator": "#2A2A25", "SeparatorStrong": "#6A675F",
            "Accent": "#FFB547", "AccentContrast": "#1A1205", "AccentInk": "#FFB547",
            "AccentSubtle": "#2A2214", "Success": "#8FD3A6", "SuccessContrast": "#0B1A10",
            "Warning": "#FFB547", "Danger": "#FF7A6B", "DangerSubtle": "#2C1613",
            "Scrim": "#000000B3",
        ],
    ]
]

@Suite("Renk token'ları")
struct ColorTokenTests {
    @Test func assetNameIsPascalCase() {
        #expect(FokusColorToken.secondaryLabel.assetName == "SecondaryLabel")
        #expect(FokusColorToken.accentInk.assetName == "AccentInk")
        #expect(FokusColorToken.scrim.assetName == "Scrim")
        #expect(FokusColorToken.surfaceElevated.assetName == "SurfaceElevated")
    }

    @Test func tokenSetMatchesWeb() {
        let names = Set(FokusColorToken.allCases.map(\.assetName))
        for palette in FokusPalette.allCases {
            #expect(names == Set(webColors[palette]?["light"]?.keys ?? [:].keys))
            #expect(names == Set(webColors[palette]?["dark"]?.keys ?? [:].keys))
        }
    }
}

@Suite("Tipografi")
struct TypographyTests {
    @Test(arguments: [
        (FokusTextStyle.display, 44.0), (.largeTitle, 36), (.title1, 28), (.title2, 22),
        (.title3, 20), (.headline, 17), (.body, 17), (.callout, 16), (.subheadline, 15),
        (.footnote, 13), (.caption, 12), (.eyebrow, 11), (.numeralHero, 72), (.numeralXL, 56),
        (.numeralLG, 36), (.numeral, 24), (.numeralSM, 17),
    ])
    func sizeMatchesWeb(style: FokusTextStyle, size: Double) {
        #expect(Double(style.size) == size)
    }

    @Test func trackingMatchesWebEm() {
        #expect(FokusTextStyle.eyebrow.trackingEm == 0.12)
        #expect(FokusTextStyle.numeralHero.trackingEm == -0.06)
        #expect(FokusTextStyle.body.tracking == 0)
        #expect(abs(FokusTextStyle.eyebrow.tracking - 1.32) < 0.001)
    }

    @Test func everyStyleHasLineHeightAtLeastSize() {
        for style in FokusTextStyle.allCases { #expect(style.lineHeight >= style.size) }
    }
}

#if canImport(UIKit)
@Suite("Gömülü kaynaklar (UIKit)")
struct ResourceTests {
    @Test(arguments: FokusPalette.allCases, [UIUserInterfaceStyle.light, .dark])
    func colorsResolveToWebHex(palette: FokusPalette, style: UIUserInterfaceStyle) throws {
        let key = style == .dark ? "dark" : "light"
        let table = try #require(webColors[palette]?[key])
        let traits = UITraitCollection(userInterfaceStyle: style)
        for token in FokusColorToken.allCases {
            let color = try #require(
                UIColor(named: "\(palette.assetFolder)/\(token.assetName)", in: .module, compatibleWith: traits),
                "Eksik asset: \(palette.assetFolder)/\(token.assetName)"
            )
            var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            let resolved = color.resolvedColor(with: traits)
            #expect(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
            let expected = try parse(#require(table[token.assetName]))
            let actual = [r, g, b, a].map { Int(($0 * 255).rounded()) }
            #expect(actual == expected, "\(palette) \(key) \(token.assetName)")
        }
    }

    @Test func fontsRegisterAndResolve() {
        FokusFonts.registerAll()
        FokusFonts.registerAll()  // idempotent
        for name in FokusFonts.allPostScriptNames {
            #expect(UIFont(name: name, size: 17) != nil, "Font bulunamadı: \(name)")
        }
    }

    @Test func fontsRegisterConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 { group.addTask { FokusFonts.registerAll() } }
        }
        #expect(UIFont(name: FokusFonts.monoRegular, size: 12) != nil)
    }

    /// `#RRGGBB[AA]` → [r, g, b, a] (0–255; alfa yoksa 255).
    private func parse(_ hex: String) throws -> [Int] {
        let h = hex.dropFirst()
        let bytes = stride(from: 0, to: h.count, by: 2).map { i -> Int in
            let s = h.index(h.startIndex, offsetBy: i)
            return Int(h[s..<h.index(s, offsetBy: 2)], radix: 16) ?? -1
        }
        return bytes.count == 3 ? bytes + [255] : bytes
    }
}
#endif
