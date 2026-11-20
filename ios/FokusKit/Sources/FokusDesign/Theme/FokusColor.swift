import SwiftUI

/// Renk token'ları — web `COLOR_TOKENS` ile aynı küme. Asset adı PascalCase (`SecondaryLabel`).
public enum FokusColorToken: String, CaseIterable, Sendable {
    case background, surface, surfaceElevated, fill, controlThumb, switchThumbOff
    case label, secondaryLabel, tertiaryLabel, separator, separatorStrong
    case accent, accentContrast, accentInk, accentSubtle
    case success, successContrast, warning, danger, dangerSubtle, scrim

    /// Asset Catalog renk adı (web `swiftUIColorName`).
    public var assetName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// Etkin palete göre çözülen renk. Kullanım: `.foregroundStyle(.fkLabel)`,
/// `.background(.fkBackground)`; `Color` gerekiyorsa `FokusColor.color(.accent, palette:)`.
public struct FokusColor: ShapeStyle, Sendable {
    public let token: FokusColorToken

    public init(_ token: FokusColorToken) {
        self.token = token
    }

    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        Self.color(token, palette: environment.fokusPalette).resolve(in: environment)
    }

    /// Belirli palet için `Color` (Any/Dark görünümünü sistem çözer).
    public static func color(_ token: FokusColorToken, palette: FokusPalette = .default) -> Color {
        Color("\(palette.assetFolder)/\(token.assetName)", bundle: .module)
    }
}

extension ShapeStyle where Self == FokusColor {
    public static var fkBackground: FokusColor { FokusColor(.background) }
    public static var fkSurface: FokusColor { FokusColor(.surface) }
    public static var fkSurfaceElevated: FokusColor { FokusColor(.surfaceElevated) }
    public static var fkFill: FokusColor { FokusColor(.fill) }
    public static var fkLabel: FokusColor { FokusColor(.label) }
    public static var fkSecondaryLabel: FokusColor { FokusColor(.secondaryLabel) }
    public static var fkTertiaryLabel: FokusColor { FokusColor(.tertiaryLabel) }
    public static var fkSeparator: FokusColor { FokusColor(.separator) }
    public static var fkSeparatorStrong: FokusColor { FokusColor(.separatorStrong) }
    public static var fkAccent: FokusColor { FokusColor(.accent) }
    public static var fkAccentContrast: FokusColor { FokusColor(.accentContrast) }
    public static var fkAccentInk: FokusColor { FokusColor(.accentInk) }
    public static var fkAccentSubtle: FokusColor { FokusColor(.accentSubtle) }
    public static var fkSuccess: FokusColor { FokusColor(.success) }
    public static var fkWarning: FokusColor { FokusColor(.warning) }
    public static var fkDanger: FokusColor { FokusColor(.danger) }
}

/// FokusDesign kaynak paketi (renk kataloğu, fontlar). Testler ve önizlemeler için.
public enum FokusDesignResources {
    public static let bundle: Bundle = .module
}
