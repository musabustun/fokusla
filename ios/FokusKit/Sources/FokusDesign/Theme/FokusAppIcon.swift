/// Palete göre uygulama ikonu. Saf kurallar; `UIApplication.setAlternateIconName` çağrısı
/// uygulama hedefindedir (`Fokus/App/AppIconSync.swift`).
///
/// Varsayılan palet (`coffee`) birincil `AppIcon`'dur (`nil`). Diğer paletlerin ikonları
/// `Fokus/Resources/Assets.xcassets/AppIcon-<Palet>.appiconset` içindedir ve
/// `ios/scripts/generate_palette_app_icons.py` ile üretilir; adlar `project.yml`'deki
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ile aynı olmalıdır (testle denetlenir).
public enum FokusAppIcon {
    /// Paletin alternatif ikon adı; varsayılan palette `nil` (birincil ikon).
    public static func alternateName(for palette: FokusPalette) -> String? {
        palette == .default ? nil : "AppIcon-\(palette.assetFolder)"
    }

    /// `@AppStorage(FokusThemeKeys.palette)` ham değerinden; bilinmeyen değer varsayılan sayılır.
    public static func alternateName(forPaletteRaw raw: String) -> String? {
        alternateName(for: FokusPalette(rawValue: raw) ?? .default)
    }

    /// Şu anki ikon (`UIApplication.alternateIconName`) temadan farklıysa `true`.
    public static func needsUpdate(current: String?, palette: FokusPalette) -> Bool {
        current != alternateName(for: palette)
    }

    /// Tüm alternatif ikon adları, palet sırasıyla.
    public static var alternateNames: [String] {
        FokusPalette.allCases.compactMap(alternateName(for:))
    }
}
