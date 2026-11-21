import CoreText
import Foundation
import os

/// Gömülü fontlar (OFL; lisanslar `Resources/Fonts/OFL-*.txt`). PostScript adları sabittir ve
/// `FokusTextStyle` bunlara bağlıdır.
public enum FokusFonts {
    public static let displayExtraBold = "BricolageGrotesque-ExtraBold"
    public static let displayMedium = "BricolageGrotesque-Medium"
    public static let monoRegular = "JetBrainsMono-Regular"
    public static let monoMedium = "JetBrainsMono-Medium"

    /// Pakette bulunması gereken tüm PostScript adları.
    public static let allPostScriptNames: [String] = [
        displayExtraBold, displayMedium, monoRegular, monoMedium,
    ]

    private static let logger = Logger(subsystem: "com.musabustun.fokus", category: "FokusDesign.fonts")

    /// Paket içindeki fontları süreç için kaydeder. Uygulama açılışında bir kez çağır; tekrar
    /// çağrılması ve eşzamanlı çağrılması güvenlidir (kayıt yalnızca ilk çağrıda yapılır).
    /// Hata olursa çökmez; `os.Logger` ile kaydedilir ve sistem fontuna düşülür.
    public static func registerAll() {
        _ = registration
    }

    /// `static let` tembel ve iş parçacığı güvenli (bir kez) başlatılır.
    private static let registration: Void = registerBundledFonts()

    private static func registerBundledFonts() {
        let urls = bundledFontURLs()
        if urls.count < allPostScriptNames.count {
            logger.error("Beklenen \(allPostScriptNames.count) font yerine \(urls.count) dosya bulundu.")
        }
        for url in urls {
            var error: Unmanaged<CFError>?
            guard !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else { continue }
            let cfError = error?.takeRetainedValue()
            let code = cfError.map { CFErrorGetCode($0) }
            // UIAppFonts ile zaten kayıtlıysa sorun yok.
            if code == CTFontManagerError.alreadyRegistered.rawValue { continue }
            let reason = cfError.map { String(describing: $0) } ?? "bilinmeyen hata"
            logger.error("Font kaydedilemedi \(url.lastPathComponent, privacy: .public): \(reason, privacy: .public)")
        }
    }

    /// SwiftPM kaynakları düzleştirebilir ya da `Fonts/` alt klasörünü koruyabilir; ikisine de bakar.
    private static func bundledFontURLs() -> [URL] {
        let bundle = Bundle.module
        let found =
            (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        var seen = Set<String>()
        return found.filter { seen.insert($0.lastPathComponent).inserted }
    }
}
