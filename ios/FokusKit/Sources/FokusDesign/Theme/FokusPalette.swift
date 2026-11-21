import SwiftUI

// Palet × görünüm (açık/koyu). Kaynak: web `web/src/ui/tokens.ts` (`PALETTES`, `PALETTE_LABELS`).

/// Renk paleti. Raw value'lar web `PaletteName` ve `@AppStorage("fokus.palette")` değerleriyle
/// BİREBİR aynıdır; sıra web `PALETTE_NAMES` (seçici sırası). Yeni palet: web'e ekle →
/// `npm run export:ios-palettes` → `python3 ios/scripts/generate_palette_assets.py` → buraya case
/// (bkz. FokusDesign/README.md). `FokusDesignTests` asset'leri ve adları web'le karşılaştırır.
public enum FokusPalette: String, CaseIterable, Identifiable, Sendable {
    /// Varsayılan "Gece mesaisi" kehribar paleti.
    case coffee
    case mono
    case strawberry
    case matcha
    case blueberry
    case lemonade

    public var id: String { rawValue }

    /// Kullanıcıya görünen ad (web `PALETTE_LABELS`).
    public var displayName: String {
        switch self {
        case .coffee: "Kahve"
        case .mono: "Tek renk"
        case .strawberry: "Çilek"
        case .matcha: "Matcha"
        case .blueberry: "Yaban mersini"
        case .lemonade: "Limonata"
        }
    }

    /// Asset Catalog klasör adı (namespace) — web `swiftUIPaletteColorName` öneki: `Coffee`.
    public var assetFolder: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public static let `default`: FokusPalette = .coffee
}

/// Görünüm tercihi.
public enum FokusAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "Cihaz ayarı"
        case .light: "Açık"
        case .dark: "Koyu"
        }
    }

    /// `.preferredColorScheme(_:)` değeri (`nil` = sistemi izle).
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public static let `default`: FokusAppearance = .system
}

/// `@AppStorage` anahtarları.
public enum FokusThemeKeys {
    /// Palet (web `PALETTE_STORAGE_KEY`).
    public static let palette = "fokus.palette"
    /// Görünüm/mod (web `THEME_STORAGE_KEY`).
    public static let appearance = "fokus.theme"
}

extension EnvironmentValues {
    /// Etkin palet. Kökte `.fokusTheme()` ayarlar.
    @Entry public var fokusPalette: FokusPalette = .default
}
