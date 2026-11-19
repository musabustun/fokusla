import SwiftUI

// SÖZLEŞME (API kararlı; implementasyon tasarım alt ajanında). Palet × görünüm (açık/koyu).

/// Renk paleti. Raw value `@AppStorage` ve web palet kimlikleriyle aynı tutulur.
/// Yeni palet: case ekle + `Colors.xcassets/<Palet>/` klasörü (bkz. ios/README.md).
public enum FokusPalette: String, CaseIterable, Identifiable, Sendable {
    /// Varsayılan "Gece mesaisi" kehribar paleti.
    case kahve

    public var id: String { rawValue }

    /// Kullanıcıya görünen ad.
    public var displayName: String {
        switch self {
        case .kahve: "Kahve"
        }
    }

    /// Asset Catalog klasör adı (namespace).
    public var assetFolder: String {
        switch self {
        case .kahve: "Kahve"
        }
    }

    public static let `default`: FokusPalette = .kahve
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
    public static let palette = "fokus.theme.palette"
    public static let appearance = "fokus.theme.appearance"
}

extension EnvironmentValues {
    /// Etkin palet. Kökte `.fokusTheme()` ayarlar.
    @Entry public var fokusPalette: FokusPalette = .default
}
