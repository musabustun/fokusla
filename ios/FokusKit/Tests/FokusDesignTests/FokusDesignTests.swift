import SwiftUI
import Testing

@testable import FokusDesign

#if canImport(UIKit)
import UIKit
#endif

/// Web `tokens.ts` paletleri — `npm run export:ios-palettes` çıktısı (`Fixtures/palettes.web.json`).
private struct WebPalettes: Decodable {
    let `default`: String
    let order: [String]
    let labels: [String: String]
    let tokens: [String]
    let palettes: [String: [String: [String: String]]]

    static let shared: WebPalettes = {
        guard
            let url = Bundle.module.url(forResource: "palettes.web", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(WebPalettes.self, from: data)
        else { fatalError("Fixtures/palettes.web.json okunamadı") }
        return decoded
    }()

    /// palet → mod → asset adı (PascalCase) → hex.
    func table(_ palette: FokusPalette, _ mode: String) -> [String: String] {
        let raw = palettes[palette.rawValue]?[mode] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.map { (pascal($0.key), $0.value) })
    }

    private func pascal(_ token: String) -> String {
        token.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}

private let web = WebPalettes.shared

@Suite("Paletler")
struct PaletteTests {
    @Test func casesMatchWebOrderAndDefault() {
        #expect(FokusPalette.allCases.map(\.rawValue) == web.order)
        #expect(FokusPalette.default.rawValue == web.default)
    }

    @Test(arguments: FokusPalette.allCases)
    func displayNameAndFolderMatchWeb(palette: FokusPalette) {
        #expect(palette.displayName == web.labels[palette.rawValue])
        #expect(palette.assetFolder == palette.rawValue.prefix(1).uppercased() + palette.rawValue.dropFirst())
    }

    @Test func storageKeysMatchWeb() {
        #expect(FokusThemeKeys.palette == "fokus.palette")
        #expect(FokusThemeKeys.appearance == "fokus.theme")
    }
}

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
            #expect(names == Set(web.table(palette, "light").keys))
            #expect(names == Set(web.table(palette, "dark").keys))
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
        let table = web.table(palette, key)
        try #require(!table.isEmpty)
        let traits = UITraitCollection(userInterfaceStyle: style)
        for token in FokusColorToken.allCases {
            let color = try #require(
                UIColor(named: "\(palette.assetFolder)/\(token.assetName)", in: FokusDesignResources.bundle, compatibleWith: traits),
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
