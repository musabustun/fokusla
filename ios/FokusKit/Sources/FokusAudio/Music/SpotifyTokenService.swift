import Foundation

/// `/api/token` yanıtından alınan anahtarlar.
public struct SpotifyTokenGrant: Equatable, Sendable {
    public var accessToken: String
    public var expiresIn: TimeInterval
    /// Yenilemede Spotify yeni bir yenileme anahtarı döndürmeyebilir; o zaman eskisi kullanılmaya devam eder.
    public var refreshToken: String?

    public init(accessToken: String, expiresIn: TimeInterval, refreshToken: String?) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
    }
}

/// Token isteği başarısızlığının sınıfı (karar için; ayrıntı günlüğe yazılır).
public enum SpotifyTokenFailure: Error, Equatable, Sendable {
    /// `invalid_grant`: yenileme anahtarı/kod geçersiz, süresi dolmuş ya da kullanıcı Spotify'da erişimi kaldırmış.
    case invalidGrant
    /// Diğer 4xx (ör. `invalid_client`): yapılandırma sorunu, tekrar denemek işe yaramaz.
    case rejected
    /// Ağ hatası, 429 ya da 5xx: anahtar korunur, sonra tekrar denenir.
    case transient
    /// 200 ama beklenmeyen gövde.
    case invalidResponse
}

/// Spotify hesap sunucusuyla (`accounts.spotify.com`) konuşan tek yüz. Testlerde sahtelenir.
public protocol SpotifyTokenServicing: Sendable {
    /// Yetkilendirme kodunu (PKCE doğrulayıcısıyla) erişim + yenileme anahtarına çevirir.
    func exchange(code: String, verifier: String) async -> Result<SpotifyTokenGrant, SpotifyTokenFailure>
    /// Yenileme anahtarıyla yeni erişim anahtarı alır (yalnızca `client_id`; secret YOK).
    func refresh(refreshToken: String) async -> Result<SpotifyTokenGrant, SpotifyTokenFailure>
}

/// `POST https://accounts.spotify.com/api/token` isteklerinin kurulması ve yanıtların yorumu (saf; birim testli).
public enum SpotifyTokenEndpoint {
    public static let url = URL(string: "https://accounts.spotify.com/api/token")!
    static let timeout: TimeInterval = 20

    public static func exchangeRequest(
        clientID: String, code: String, verifier: String, redirectURL: URL
    ) -> URLRequest {
        request([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirectURL.absoluteString),
            ("client_id", clientID),
            ("code_verifier", verifier),
        ])
    }

    public static func refreshRequest(clientID: String, refreshToken: String) -> URLRequest {
        request([
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", clientID),
        ])
    }

    private static func request(_ parameters: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(SpotifyFormEncoding.encode(parameters).utf8)
        return request
    }

    private struct SuccessBody: Decodable {
        let accessToken: String
        let expiresIn: Double
        let refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    private struct ErrorBody: Decodable {
        let error: String?
    }

    /// HTTP durum kodu + gövde → anahtar ya da hata sınıfı.
    public static func interpret(statusCode: Int, body: Data) -> Result<SpotifyTokenGrant, SpotifyTokenFailure> {
        switch statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(SuccessBody.self, from: body),
                !decoded.accessToken.isEmpty, decoded.expiresIn > 0
            else { return .failure(.invalidResponse) }
            let refresh = decoded.refreshToken.flatMap { $0.isEmpty ? nil : $0 }
            return .success(
                SpotifyTokenGrant(
                    accessToken: decoded.accessToken, expiresIn: decoded.expiresIn, refreshToken: refresh))
        case 429, 500...599:
            return .failure(.transient)
        case 400...499:
            let error = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.error
            return .failure(error == "invalid_grant" ? .invalidGrant : .rejected)
        default:
            return .failure(.invalidResponse)
        }
    }
}

/// Gerçek ağ uygulaması: yalnızca `accounts.spotify.com/api/token`'a, çerez/önbellek tutmayan (ephemeral)
/// bir oturumla gider. Client Secret YOKTUR. Taşıma testlerde sahtelenir.
public struct URLSessionSpotifyTokenService: SpotifyTokenServicing {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let clientID: String
    private let redirectURL: URL
    private let transport: Transport

    public init(clientID: String, redirectURL: URL, transport: Transport? = nil) {
        self.clientID = clientID
        self.redirectURL = redirectURL
        self.transport = transport ?? Self.ephemeralTransport()
    }

    public func exchange(code: String, verifier: String) async -> Result<SpotifyTokenGrant, SpotifyTokenFailure> {
        await send(
            SpotifyTokenEndpoint.exchangeRequest(
                clientID: clientID, code: code, verifier: verifier, redirectURL: redirectURL))
    }

    public func refresh(refreshToken: String) async -> Result<SpotifyTokenGrant, SpotifyTokenFailure> {
        await send(SpotifyTokenEndpoint.refreshRequest(clientID: clientID, refreshToken: refreshToken))
    }

    private func send(_ request: URLRequest) async -> Result<SpotifyTokenGrant, SpotifyTokenFailure> {
        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
            return SpotifyTokenEndpoint.interpret(statusCode: http.statusCode, body: data)
        } catch {
            return .failure(.transient)
        }
    }

    private static func ephemeralTransport() -> Transport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        return { request in try await session.data(for: request) }
    }
}
