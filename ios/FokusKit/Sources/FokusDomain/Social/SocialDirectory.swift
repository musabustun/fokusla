import CryptoKit
import Foundation

/// Kullanıcı adı dizini: public veritabanında ad değil, adın özeti durur. Kayıt yalnızca tam ad bilinirse
/// bulunur; dizin sorgulanamaz/listelenemez (docs/social-cloudkit.md 3).
public enum SocialDirectory {
    private static let context = "fokus.username.v1:"

    /// `username` daha önce `SocialCalc.validateUsername` ile normalleştirilmiş olmalıdır.
    public static func claimKey(forUsername username: String) -> String {
        let digest = SHA256.hash(data: Data((context + username).utf8))
        return "u1-" + digest.map { String(format: "%02x", $0) }.joined()
    }
}
