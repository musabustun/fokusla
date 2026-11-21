import SwiftUI

/// Kök görünüme uygulanır: `@AppStorage`'daki palet ve görünüm tercihini okur, paleti ortama
/// yazar, `preferredColorScheme` ve vurgu rengini (`tint`) ayarlar.
public struct FokusThemeModifier: ViewModifier {
    @AppStorage(FokusThemeKeys.palette) private var paletteRaw = FokusPalette.default.rawValue
    @AppStorage(FokusThemeKeys.appearance) private var appearanceRaw = FokusAppearance.default.rawValue

    public init() {}

    public func body(content: Content) -> some View {
        let palette = FokusPalette(rawValue: paletteRaw) ?? .default
        let appearance = FokusAppearance(rawValue: appearanceRaw) ?? .default
        content
            .environment(\.fokusPalette, palette)
            .tint(FokusColor.color(.accentInk, palette: palette))
            .preferredColorScheme(appearance.colorScheme)
    }
}

extension View {
    /// Fokus temasını uygular (uygulama kökünde bir kez).
    public func fokusTheme() -> some View {
        modifier(FokusThemeModifier())
    }
}
