import CryptoKit
import Foundation
import Security

/// Spotify "Authorization Code with PKCE" akışının saf parçaları (RFC 7636). Client Secret YOKTUR ve
/// gerekmez: kodu token'a çevirmek için yalnızca `client_id` + `code_verifier` gönderilir. Birim testli.
public struct SpotifyPKCE: Equatable, Sendable {
    /// 64 rastgele bayt → 86 karakterlik base64url doğrulayıcı (RFC 7636: 43…128 karakter).
    public static let verifierByteCount = 64
    static let allowedVerifierCharacters = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = Self.challenge(for: verifier)
    }

    /// Kriptografik rastgele doğrulayıcı üretir. `randomBytes` testlerde sabitlenir.
    public static func generate(
        randomBytes: (Int) -> [UInt8] = SpotifyPKCE.secureRandomBytes
    ) -> SpotifyPKCE {
        SpotifyPKCE(verifier: base64URL(Data(randomBytes(verifierByteCount))))
    }

    /// CSRF'e karşı `state` değeri (16 rastgele bayt, base64url).
    public static func makeState(randomBytes: (Int) -> [UInt8] = SpotifyPKCE.secureRandomBytes) -> String {
        base64URL(Data(randomBytes(16)))
    }

    /// `code_challenge` = base64url(SHA256(ASCII(verifier))), dolgusuz (`S256`).
    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// RFC 7636 4.1: 43…128 karakter, yalnızca `[A-Z a-z 0-9 - . _ ~]`.
    public static func isValidVerifier(_ verifier: String) -> Bool {
        (43...128).contains(verifier.count) && verifier.allSatisfy(allowedVerifierCharacters.contains)
    }

    /// Dolgusuz base64url (`+` → `-`, `/` → `_`, `=` atılır).
    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func secureRandomBytes(_ count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes başarısız: \(status)")
        return bytes
    }
}

/// `https://accounts.spotify.com/authorize` isteği (kod + PKCE). Kapsam yalnızca `app-remote-control`:
/// profil, e-posta, kütüphane ya da çalma geçmişi istenmez.
public struct SpotifyAuthorizationRequest: Equatable, Sendable {
    public static let endpoint = URL(string: "https://accounts.spotify.com/authorize")!
    public static let scopes = ["app-remote-control"]

    public let clientID: String
    public let redirectURL: URL
    public let codeChallenge: String
    public let state: String

    public init(clientID: String, redirectURL: URL, codeChallenge: String, state: String) {
        self.clientID = clientID
        self.redirectURL = redirectURL
        self.codeChallenge = codeChallenge
        self.state = state
    }

    public var parameters: [(String, String)] {
        [
            ("client_id", clientID),
            ("response_type", "code"),
            ("redirect_uri", redirectURL.absoluteString),
            ("code_challenge_method", "S256"),
            ("code_challenge", codeChallenge),
            ("scope", Self.scopes.joined(separator: " ")),
            ("state", state),
        ]
    }

    public var url: URL {
        var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = SpotifyFormEncoding.encode(parameters)
        return components.url!
    }
}

/// `application/x-www-form-urlencoded` / sorgu kodlaması: yalnızca RFC 3986 "unreserved" karakterler
/// kodlanmadan kalır (`fokus://…` içindeki `:` ve `/` da kodlanır).
public enum SpotifyFormEncoding {
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func encode(_ parameters: [(String, String)]) -> String {
        parameters
            .map { "\(escape($0.0))=\(escape($0.1))" }
            .joined(separator: "&")
    }

    static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}

/// Web yetkilendirmesinden dönen `fokus://spotify-callback?code=…&state=…` bağlantısının yorumu.
public enum SpotifyCodeCallback: Equatable, Sendable {
    case code(String)
    case failure(MusicProviderError)

    /// `state` eşleşmezse (CSRF / eski istek) kod KULLANILMAZ. `error=access_denied` → reddedildi.
    public static func interpret(_ url: URL, expectedState: String) -> SpotifyCodeCallback {
        let parameters = SpotifyAuthCallback.parameters(from: url)
        guard !expectedState.isEmpty, parameters["state"] == expectedState else { return .failure(.unknown) }
        if let code = parameters["code"], !code.isEmpty { return .code(code) }
        return parameters["error"] == "access_denied" ? .failure(.authorizationDenied) : .failure(.unknown)
    }
}

/// Uygulama içi web yetkilendirme oturumunun sonucu (`ASWebAuthenticationSession`).
public enum SpotifyWebAuthResult: Equatable, Sendable {
    case callback(URL)
    /// Kullanıcı sayfayı kapattı.
    case cancelled
    case failed
}

/// Uygulama içi web yetkilendirmesi (gerçeği `ASWebAuthenticationSession`, uygulama hedefinde; testlerde sahte).
@MainActor
public protocol SpotifyWebAuthenticating: AnyObject {
    func authenticate(url: URL, callbackScheme: String) async -> SpotifyWebAuthResult
}
