import Foundation

/// Kullanıcı adı ve oda adı için küçük, cihazda çalışan uygunsuz söz süzgeci (App Store 1.2).
/// Yalnız TAM kelime eşleşir ("klasik" gibi masum kelimeler takılmaz).
public enum SocialContentFilter {
    private static let blockedWords: Set<String> = [
        "amk", "aq", "amcik", "amına", "amina", "gavat", "got", "göt", "ibne", "kahpe", "orospu", "oç", "oc",
        "pezevenk", "pic", "piç", "sik", "sikerim", "sikik", "siktir", "surtuk", "sürtük", "yarak", "yarrak",
        "fuck", "shit", "bitch", "nigger", "cunt",
    ]

    private static let turkish = Locale(identifier: "tr_TR")

    public static func isAcceptable(_ text: String) -> Bool {
        !text.lowercased(with: turkish)
            .components(separatedBy: CharacterSet.letters.inverted)
            .contains(where: blockedWords.contains)
    }
}
