import Foundation
import Testing

@testable import FokusDesign

@Suite("FokusAppIcon")
struct FokusAppIconTests {
    @Test(
        "Palet → alternatif ikon adı",
        arguments: [
            (FokusPalette.coffee, String?.none),
            (.mono, "AppIcon-Mono"),
            (.strawberry, "AppIcon-Strawberry"),
            (.matcha, "AppIcon-Matcha"),
            (.blueberry, "AppIcon-Blueberry"),
            (.lemonade, "AppIcon-Lemonade"),
        ]
    )
    func alternateName(palette: FokusPalette, expected: String?) {
        #expect(FokusAppIcon.alternateName(for: palette) == expected)
    }

    @Test("Her palet tabloda: varsayılan nil, diğerleri benzersiz ad")
    func coversEveryPalette() {
        #expect(FokusAppIcon.alternateName(for: .default) == nil)
        let names = FokusPalette.allCases.compactMap(FokusAppIcon.alternateName(for:))
        #expect(names.count == FokusPalette.allCases.count - 1)
        #expect(Set(names).count == names.count)
        #expect(FokusAppIcon.alternateNames == names)
    }

    @Test(
        "Yalnızca ikon temadan farklıysa değiştir",
        arguments: [
            (String?.none, FokusPalette.coffee, false),
            (String?.none, .strawberry, true),
            ("AppIcon-Strawberry", .strawberry, false),
            ("AppIcon-Strawberry", .coffee, true),
            ("AppIcon-Strawberry", .matcha, true),
            ("AppIcon-Mono", .mono, false),
        ]
    )
    func needsUpdate(current: String?, palette: FokusPalette, expected: Bool) {
        #expect(FokusAppIcon.needsUpdate(current: current, palette: palette) == expected)
    }

    @Test("Ham palet değeri: bilinmeyen değer varsayılana düşer")
    func paletteFromRawValue() {
        #expect(FokusAppIcon.alternateName(forPaletteRaw: "matcha") == "AppIcon-Matcha")
        #expect(FokusAppIcon.alternateName(forPaletteRaw: "coffee") == nil)
        #expect(FokusAppIcon.alternateName(forPaletteRaw: "yok-boyle-palet") == nil)
    }

    /// Uygulama hedefi (asset catalog + `project.yml`) ile ad listesi eşit kalmalı:
    /// `ios/scripts/generate_palette_app_icons.py` ikonları, `project.yml` derleme ayarını taşır.
    @Test("Her ad için appiconset ve derleme ayarı var")
    func assetsAndBuildSettingMatch() throws {
        let iosDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // FokusDesignTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // FokusKit
            .deletingLastPathComponent()  // ios
        let assets = iosDir.appending(path: "Fokus/Resources/Assets.xcassets")
        for name in FokusAppIcon.alternateNames {
            let contents = assets.appending(path: "\(name).appiconset/Contents.json")
            #expect(FileManager.default.fileExists(atPath: contents.path), "\(name) eksik")
        }
        let projectYML = try String(contentsOf: iosDir.appending(path: "project.yml"), encoding: .utf8)
        let expectedSetting = "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES: "
            + FokusAppIcon.alternateNames.joined(separator: " ")
        #expect(projectYML.contains(expectedSetting))
    }
}
