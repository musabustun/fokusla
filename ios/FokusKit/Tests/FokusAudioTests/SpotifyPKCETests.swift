import Foundation
import Testing

@testable import FokusAudio

// MARK: - PKCE

@Suite("SpotifyPKCE")
struct SpotifyPKCETests {
    @Test("RFC 7636 Ek B test vektörü")
    func rfcVector() {
        let pkce = SpotifyPKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("üretilen doğrulayıcı 86 karakter, geçerli ve dolgusuz")
    func generated() {
        let pkce = SpotifyPKCE.generate(randomBytes: { Array(repeating: 0xFB, count: $0) })
        #expect(pkce.verifier.count == 86)
        #expect(SpotifyPKCE.isValidVerifier(pkce.verifier))
        #expect(!pkce.verifier.contains("=") && !pkce.verifier.contains("+") && !pkce.verifier.contains("/"))
        #expect(pkce.challenge == SpotifyPKCE.challenge(for: pkce.verifier))
        #expect(pkce.challenge.count == 43)
    }

    @Test("gerçek rastgele doğrulayıcılar farklıdır")
    func randomness() {
        #expect(SpotifyPKCE.generate().verifier != SpotifyPKCE.generate().verifier)
        #expect(SpotifyPKCE.makeState() != SpotifyPKCE.makeState())
    }

    @Test(
        "doğrulayıcı kuralları",
        arguments: [
            (String(repeating: "a", count: 43), true),
            (String(repeating: "a", count: 42), false),
            (String(repeating: "a", count: 128), true),
            (String(repeating: "a", count: 129), false),
            (String(repeating: "a", count: 42) + "~", true),
            (String(repeating: "a", count: 42) + "+", false),
            (String(repeating: "a", count: 42) + "ç", false),
        ])
    func verifierRules(verifier: String, isValid: Bool) {
        #expect(SpotifyPKCE.isValidVerifier(verifier) == isValid)
    }

    @Test("yetkilendirme adresi: kod + S256 + yalnızca app-remote-control, redirect kodlanır")
    func authorizationURL() throws {
        let request = SpotifyAuthorizationRequest(
            clientID: "cid", redirectURL: URL(string: "fokus://spotify-callback")!, codeChallenge: "chal",
            state: "st")
        let url = request.url
        #expect(url.absoluteString.hasPrefix("https://accounts.spotify.com/authorize?"))
        #expect(url.absoluteString.contains("redirect_uri=fokus%3A%2F%2Fspotify-callback"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(
            query == [
                "client_id": "cid", "response_type": "code", "redirect_uri": "fokus://spotify-callback",
                "code_challenge_method": "S256", "code_challenge": "chal", "scope": "app-remote-control",
                "state": "st",
            ])
    }

    @Test(
        "web dönüşü yorumu",
        arguments: [
            ("fokus://spotify-callback?code=abc&state=st", SpotifyCodeCallback.code("abc")),
            ("fokus://spotify-callback?code=abc&state=other", .failure(.unknown)),
            ("fokus://spotify-callback?code=abc", .failure(.unknown)),
            ("fokus://spotify-callback?error=access_denied&state=st", .failure(.authorizationDenied)),
            ("fokus://spotify-callback?error=server_error&state=st", .failure(.unknown)),
            ("fokus://spotify-callback?code=&state=st", .failure(.unknown)),
        ])
    func codeCallback(url: String, expected: SpotifyCodeCallback) {
        #expect(SpotifyCodeCallback.interpret(URL(string: url)!, expectedState: "st") == expected)
    }

    @Test("boş beklenen state hiçbir kodu kabul etmez")
    func emptyExpectedState() {
        let url = URL(string: "fokus://spotify-callback?code=abc&state=")!
        #expect(SpotifyCodeCallback.interpret(url, expectedState: "") == .failure(.unknown))
    }
}

// MARK: - Token uç noktası

private let successBody =
    #"{"access_token":"A","token_type":"Bearer","expires_in":3600,"refresh_token":"R","scope":"app-remote-control"}"#

@Suite("SpotifyTokenEndpoint")
struct SpotifyTokenEndpointTests {
    private func form(_ request: URLRequest) -> [String: String] {
        var components = URLComponents()
        components.percentEncodedQuery = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    @Test("kod değişimi isteği: yalnızca client_id + code_verifier, secret yok")
    func exchangeRequest() {
        let request = SpotifyTokenEndpoint.exchangeRequest(
            clientID: "cid", code: "c0de", verifier: "ver", redirectURL: URL(string: "fokus://spotify-callback")!)
        #expect(request.url?.absoluteString == "https://accounts.spotify.com/api/token")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(
            form(request) == [
                "grant_type": "authorization_code", "code": "c0de", "redirect_uri": "fokus://spotify-callback",
                "client_id": "cid", "code_verifier": "ver",
            ])
    }

    @Test("yenileme isteği: grant_type=refresh_token, refresh_token, client_id")
    func refreshRequest() {
        let request = SpotifyTokenEndpoint.refreshRequest(clientID: "cid", refreshToken: "r/+=1")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(form(request) == ["grant_type": "refresh_token", "refresh_token": "r/+=1", "client_id": "cid"])
    }

    @Test(
        "yanıt yorumu",
        arguments: [
            (
                200, successBody,
                Result<SpotifyTokenGrant, SpotifyTokenFailure>.success(
                    SpotifyTokenGrant(accessToken: "A", expiresIn: 3600, refreshToken: "R"))
            ),
            (
                200, #"{"access_token":"A","token_type":"Bearer","expires_in":3600}"#,
                .success(SpotifyTokenGrant(accessToken: "A", expiresIn: 3600, refreshToken: nil))
            ),
            (
                200, #"{"access_token":"A","expires_in":3600,"refresh_token":""}"#,
                .success(SpotifyTokenGrant(accessToken: "A", expiresIn: 3600, refreshToken: nil))
            ),
            (200, #"{"access_token":"","expires_in":3600}"#, .failure(.invalidResponse)),
            (200, #"{"expires_in":3600}"#, .failure(.invalidResponse)),
            (200, "not json", .failure(.invalidResponse)),
            (400, #"{"error":"invalid_grant","error_description":"Refresh token revoked"}"#, .failure(.invalidGrant)),
            (400, #"{"error":"invalid_client"}"#, .failure(.rejected)),
            (401, "", .failure(.rejected)),
            (429, "", .failure(.transient)),
            (503, "", .failure(.transient)),
            (302, "", .failure(.invalidResponse)),
        ])
    func interpret(status: Int, body: String, expected: Result<SpotifyTokenGrant, SpotifyTokenFailure>) {
        #expect(SpotifyTokenEndpoint.interpret(statusCode: status, body: Data(body.utf8)) == expected)
    }

    @Test("URLSession servisi: isteği taşımaya verir, ağ hatası geçici sayılır")
    func service() async {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        let expected = Result<SpotifyTokenGrant, SpotifyTokenFailure>.success(
            SpotifyTokenGrant(accessToken: "A", expiresIn: 3600, refreshToken: "R"))
        let ok = URLSessionSpotifyTokenService(
            clientID: "cid", redirectURL: URL(string: "fokus://spotify-callback")!,
            transport: { request in
                #expect(request.url == url)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(successBody.utf8), response)
            })
        #expect(await ok.refresh(refreshToken: "R") == expected)
        #expect(await ok.exchange(code: "c", verifier: "v") == expected)

        let offline = URLSessionSpotifyTokenService(
            clientID: "cid", redirectURL: url, transport: { _ in throw URLError(.notConnectedToInternet) })
        #expect(await offline.refresh(refreshToken: "R") == .failure(.transient))

        let notHTTP = URLSessionSpotifyTokenService(
            clientID: "cid", redirectURL: url,
            transport: { _ in
                (Data(), URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
            })
        #expect(await notHTTP.refresh(refreshToken: "R") == .failure(.invalidResponse))
    }
}

// MARK: - Kayıt ve politika

@Suite("Spotify yenileme kaydı ve politikası")
struct SpotifyRefreshPolicyTests {
    @Test("yenilemede yeni anahtar gelmezse eskisi korunur, gelirse değişir")
    func grantRecord() {
        let keep = SpotifyTokenRecord(
            grant: SpotifyTokenGrant(accessToken: "A", expiresIn: 3600, refreshToken: nil), issuedAt: testEpoch,
            previousRefreshToken: "old")
        #expect(keep.refreshToken == "old")
        #expect(keep.canRefresh)
        let rotate = SpotifyTokenRecord(
            grant: SpotifyTokenGrant(accessToken: "A", expiresIn: 1800, refreshToken: "new"), issuedAt: testEpoch,
            previousRefreshToken: "old")
        #expect(rotate.refreshToken == "new")
        #expect(rotate.expiresAt == testEpoch.addingTimeInterval(1800))
    }

    @Test("ömür 0…3600 sn'ye sınırlanır; boş yenileme anahtarı yok sayılır")
    func lifetimeClamp() {
        let long = SpotifyTokenRecord(accessToken: "A", issuedAt: testEpoch, lifetime: 86_400, refreshToken: "")
        #expect(long.expiresAt == testEpoch.addingTimeInterval(3600))
        #expect(long.state(at: testEpoch) == .valid)
        #expect(!long.canRefresh)
    }

    @Test("1.0 kaydı (refreshToken alanı yok) çözülür; yeni kayıt gidiş-dönüşte korunur")
    func legacyDecoding() throws {
        let legacy = #"{"accessToken":"A","expiresAt":0}"#
        let decoded = try JSONDecoder().decode(SpotifyTokenRecord.self, from: Data(legacy.utf8))
        #expect(decoded.refreshToken == nil)
        let record = SpotifyTokenRecord(accessToken: "A", issuedAt: testEpoch, refreshToken: "R")
        let roundTrip = try JSONDecoder().decode(SpotifyTokenRecord.self, from: JSONEncoder().encode(record))
        #expect(roundTrip == record)
    }

    @Test(
        "öne gelince karar (yenilemeli)",
        arguments: [
            (
                true, SpotifyConnectionPolicy.TokenState.valid, true,
                SpotifyConnectionPolicy.ActivationAction.silentConnect
            ),
            (true, .expired, true, .refreshThenConnect),
            (true, .missing, true, .refreshThenConnect),
            (true, .expired, false, .needsReconnect),
            (false, .expired, true, .none),
        ])
    func activation(
        wants: Bool, state: SpotifyConnectionPolicy.TokenState, canRefresh: Bool,
        expected: SpotifyConnectionPolicy.ActivationAction
    ) {
        #expect(
            SpotifyConnectionPolicy.activationAction(
                wantsConnection: wants, tokenState: state, canRefresh: canRefresh, isConnected: false,
                isAttemptInFlight: false) == expected)
        #expect(
            SpotifyConnectionPolicy.activationAction(
                wantsConnection: wants, tokenState: state, canRefresh: canRefresh, isConnected: false,
                isAttemptInFlight: true) == .none)
    }

    @Test(
        "token hatası kararı",
        arguments: [
            (SpotifyTokenFailure.invalidGrant, true, SpotifyConnectionPolicy.TokenFailureAction.reauthorize),
            (.invalidGrant, false, .showReconnect(discardCredentials: true, error: .connectionLost)),
            (.rejected, true, .reauthorize),
            (.rejected, false, .showReconnect(discardCredentials: true, error: .connectionLost)),
            (.transient, true, .showReconnect(discardCredentials: false, error: .unknown)),
            (.transient, false, .showReconnect(discardCredentials: false, error: .connectionLost)),
            (.invalidResponse, false, .showReconnect(discardCredentials: false, error: .connectionLost)),
        ])
    func tokenFailure(
        failure: SpotifyTokenFailure, userInitiated: Bool, expected: SpotifyConnectionPolicy.TokenFailureAction
    ) {
        #expect(SpotifyConnectionPolicy.actionAfterTokenFailure(failure, isUserInitiated: userInitiated) == expected)
    }
}

// MARK: - Durum makinesi (PKCE + yenileme)

typealias TokenResult = Result<SpotifyTokenGrant, SpotifyTokenFailure>

final class FakeTokenService: SpotifyTokenServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var refreshResults: [TokenResult] = []
    private var exchangeResult: TokenResult = .failure(.transient)
    private var refreshLog: [String] = []
    private var exchangeLog: [String] = []
    private var holdNext = false
    private var held: CheckedContinuation<TokenResult, Never>?

    var refreshCalls: [String] { lock.withLock { refreshLog } }
    var exchangeCalls: [String] { lock.withLock { exchangeLog } }

    func queueRefresh(_ result: TokenResult) { lock.withLock { refreshResults.append(result) } }
    func setExchange(_ result: TokenResult) { lock.withLock { exchangeResult = result } }
    func holdNextRefresh() { lock.withLock { holdNext = true } }

    func releaseHeld(_ result: TokenResult) {
        let continuation = lock.withLock { () -> CheckedContinuation<TokenResult, Never>? in
            defer { held = nil }
            return held
        }
        continuation?.resume(returning: result)
    }

    func exchange(code: String, verifier: String) async -> TokenResult {
        lock.withLock {
            exchangeLog.append("\(code)|\(verifier)")
            return exchangeResult
        }
    }

    func refresh(refreshToken: String) async -> TokenResult {
        let shouldHold = lock.withLock { () -> Bool in
            refreshLog.append(refreshToken)
            defer { holdNext = false }
            return holdNext
        }
        if shouldHold {
            return await withCheckedContinuation { continuation in
                lock.withLock { held = continuation }
            }
        }
        return lock.withLock { refreshResults.isEmpty ? .failure(.transient) : refreshResults.removeFirst() }
    }
}

@MainActor
final class FakeWebAuthenticator: SpotifyWebAuthenticating {
    var result: (URL) -> SpotifyWebAuthResult = { _ in .cancelled }
    private(set) var urls: [URL] = []

    func authenticate(url: URL, callbackScheme: String) async -> SpotifyWebAuthResult {
        urls.append(url)
        return result(url)
    }
}

@MainActor final class TestClock { var now = testEpoch }

@MainActor
struct PKCEHarness {
    static let verifier = SpotifyPKCE(verifier: String(repeating: "v", count: 64))

    let remote = FakeSpotifyRemote()
    let scheduler = FakeSpotifyScheduler()
    let store: InMemorySpotifyTokenStore
    let service = FakeTokenService()
    let web = FakeWebAuthenticator()
    let clock = TestClock()
    let provider: SpotifyMusicProvider

    init(stored: SpotifyTokenRecord? = nil) {
        let store = InMemorySpotifyTokenStore(stored)
        let clock = clock
        self.store = store
        provider = SpotifyMusicProvider(
            remote: remote, tokenStore: store, canOpenURL: { _ in true }, now: { clock.now },
            scheduler: scheduler,
            pkce: SpotifyPKCEAuthorization(
                clientID: "cid", tokenService: service, webAuthenticator: web,
                makePKCE: { Self.verifier }, makeState: { "st8" }))
    }

    /// Web sayfası izin verip kodu döndürür.
    func approveInBrowser(code: String = "c0de") {
        web.result = { _ in .callback(URL(string: "fokus://spotify-callback?code=\(code)&state=st8")!) }
    }

    /// Süren web/yenileme işlerinin bitmesini bekler.
    func settle() async {
        for _ in 0..<50 {
            if let task = provider.authTask { await task.value } else { await Task.yield() }
        }
    }
}

private func grant(_ access: String, refresh: String? = nil) -> TokenResult {
    .success(SpotifyTokenGrant(accessToken: access, expiresIn: 3600, refreshToken: refresh))
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<1000 where !condition() {
        await Task.yield()
    }
}

private func stored(_ access: String = "old", refresh: String? = "R1") -> SpotifyTokenRecord {
    SpotifyTokenRecord(accessToken: access, issuedAt: testEpoch, refreshToken: refresh)
}

/// Soğuk açılışta Spotify çalışmıyor: öne gelişteki sessiz bağlanma ve tüm otomatik tekrarlar başarısız olur.
@MainActor
private func exhaustAutomaticRetries(_ h: PKCEHarness) {
    h.provider.sceneDidBecomeActive()
    for _ in 0..<SpotifyConnectionPolicy.maxAutomaticAttempts {
        h.remote.emitConnectionFailed()
        if h.scheduler.pendingCount > 0 { h.scheduler.fireLatest() }
    }
}

/// Erişim anahtarının süresi dolduktan sonraki bir an.
private let afterExpiry = testEpoch.addingTimeInterval(4000)

@MainActor
@Suite("SpotifyMusicProvider kalıcı bağlantı (PKCE + yenileme)")
struct SpotifyPersistentConnectionTests {
    @Test("ilk bağlanma: web izni → kod değişimi → yenileme anahtarı Keychain'e → sessiz bağlan")
    func firstConnect() async throws {
        let h = PKCEHarness()
        h.approveInBrowser()
        h.service.setExchange(grant("A1", refresh: "R1"))

        h.provider.connect()
        await h.settle()

        let url = try #require(h.web.urls.first)
        #expect(url.absoluteString.contains("code_challenge=\(PKCEHarness.verifier.challenge)"))
        #expect(url.absoluteString.contains("state=st8"))
        #expect(h.service.exchangeCalls == ["c0de|\(PKCEHarness.verifier.verifier)"])
        #expect(h.store.load()?.refreshToken == "R1")
        #expect(h.store.load()?.accessToken == "A1")
        #expect(h.remote.tokens.last == "A1")
        #expect(h.remote.connectCount == 1)
        #expect(h.remote.authorizeCount == 0)
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("web sayfası kapatılırsa izin reddedildi; state uyuşmazsa kod kullanılmaz; değişim hatası")
    func webFailures() async {
        let cancelled = PKCEHarness()
        cancelled.provider.connect()
        await cancelled.settle()
        #expect(cancelled.provider.connectionState == .failed(.authorizationDenied))
        #expect(cancelled.store.load() == nil)

        let forged = PKCEHarness()
        forged.web.result = { _ in .callback(URL(string: "fokus://spotify-callback?code=x&state=evil")!) }
        forged.provider.connect()
        await forged.settle()
        #expect(forged.service.exchangeCalls.isEmpty)
        #expect(forged.provider.connectionState == .failed(.unknown))

        let badExchange = PKCEHarness()
        badExchange.approveInBrowser()
        badExchange.service.setExchange(.failure(.rejected))
        badExchange.provider.connect()
        await badExchange.settle()
        #expect(badExchange.provider.connectionState == .failed(.unknown))
        #expect(badExchange.store.load() == nil)
    }

    @Test("süresi dolmuş anahtar öne gelişte sessizce yenilenir; yeni yenileme anahtarı kaydedilir")
    func refreshOnActivation() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = testEpoch.addingTimeInterval(5 * 3600)
        h.service.queueRefresh(grant("A2", refresh: "R2"))

        h.provider.sceneDidBecomeActive()
        #expect(h.provider.connectionState == .connecting)
        await h.settle()

        #expect(h.service.refreshCalls == ["R1"])
        #expect(h.store.load()?.accessToken == "A2")
        #expect(h.store.load()?.refreshToken == "R2")
        #expect(h.remote.tokens.last == "A2")
        #expect(h.web.urls.isEmpty)
        #expect(h.remote.authorizeCount == 0)
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("yenilemede yeni anahtar gelmezse eski yenileme anahtarı korunur")
    func refreshKeepsOldRefreshToken() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.service.queueRefresh(grant("A2"))
        h.provider.sceneDidBecomeActive()
        await h.settle()
        #expect(h.store.load()?.refreshToken == "R1")
        #expect(h.store.load()?.accessToken == "A2")
    }

    @Test("otomatik yenilemede invalid_grant: anahtarlar silinir, web sayfası açılmaz; dokununca izin istenir")
    func revokedAutomatic() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.service.queueRefresh(.failure(.invalidGrant))
        h.provider.sceneDidBecomeActive()
        await h.settle()

        #expect(h.store.load() == nil)
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.web.urls.isEmpty)

        h.provider.connect()
        await h.settle()
        #expect(h.web.urls.count == 1)
    }

    @Test("kullanıcı dokunuşunda invalid_grant: hemen web izni istenir")
    func revokedUserInitiated() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.provider.sceneDidBecomeActive()  // geçici hata (kuyruk boş) → "Yeniden bağlan"
        await h.settle()
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.store.load()?.refreshToken == "R1")

        h.service.queueRefresh(.failure(.invalidGrant))
        h.approveInBrowser()
        h.service.setExchange(grant("A9", refresh: "R9"))
        h.provider.connect()
        await h.settle()
        #expect(h.service.refreshCalls == ["R1", "R1"])
        #expect(h.web.urls.count == 1)
        #expect(h.store.load()?.refreshToken == "R9")
        #expect(h.remote.connectCount == 1)
    }

    @Test("ağ hatası yenileme anahtarını korur; sonraki öne gelişte yeniden denenir")
    func transientKeepsCredentials() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.service.queueRefresh(.failure(.transient))
        h.provider.sceneDidBecomeActive()
        await h.settle()
        #expect(h.store.load()?.refreshToken == "R1")
        #expect(h.provider.connectionState == .failed(.connectionLost))

        h.service.queueRefresh(grant("A2"))
        h.provider.sceneDidBecomeActive()
        await h.settle()
        #expect(h.service.refreshCalls == ["R1", "R1"])
        #expect(h.remote.connectCount == 1)
    }

    @Test("Spotify çalışmıyorsa: dokununca App Remote ile uyandırılır, yenileme anahtarı korunur")
    func wakeSpotifyKeepsRefreshToken() {
        let h = PKCEHarness(stored: stored("A1"))
        exhaustAutomaticRetries(h)
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.remote.authorizeCount == 0)  // otomatik denemede Spotify'a fırlatılmaz
        h.provider.connect()
        h.remote.emitConnectionFailed()
        #expect(h.remote.authorizeCount == 1)
        #expect(h.web.urls.isEmpty)
        #expect(h.store.load()?.refreshToken == "R1")

        #expect(h.provider.handleOpenURL(URL(string: "fokus://spotify-callback#access_token=wake")!))
        #expect(h.store.load()?.accessToken == "wake")
        #expect(h.store.load()?.refreshToken == "R1")
        #expect(h.remote.tokens.last == "wake")
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("uyandırmadan sonra da bağlanamazsa yenileme anahtarı silinmez")
    func wakeFailureKeepsCredentials() {
        let h = PKCEHarness(stored: stored("A1"))
        exhaustAutomaticRetries(h)
        h.provider.connect()
        h.remote.emitConnectionFailed()
        _ = h.provider.handleOpenURL(URL(string: "fokus://spotify-callback#access_token=wake")!)
        h.remote.emitConnectionFailed()
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.store.load()?.refreshToken == "R1")
    }

    @Test("yenileme sürerken arka plana geçilirse sonuç kaydedilir, dönüşte ikinci yenileme yapılmaz")
    func backgroundDuringRefresh() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.service.holdNextRefresh()
        h.provider.sceneDidBecomeActive()
        await waitUntil { h.service.refreshCalls.count == 1 }

        h.provider.sceneWillResignActive()
        h.provider.sceneDidBecomeActive()  // yenileme sürüyor: ikinci istek yok
        #expect(h.service.refreshCalls.count == 1)

        h.provider.sceneWillResignActive()
        let task = h.provider.authTask
        h.service.releaseHeld(grant("A2", refresh: "R2"))
        await task?.value
        #expect(h.store.load()?.refreshToken == "R2")
        #expect(h.remote.connectCount == 0)  // arka planda bağlanılmaz

        h.provider.sceneDidBecomeActive()
        #expect(h.remote.tokens.last == "A2")
        #expect(h.remote.connectCount == 1)
        #expect(h.service.refreshCalls.count == 1)
    }

    @Test("yenileme sürerken bağlantı kesilirse sonuç yok sayılır")
    func disconnectDuringRefresh() async {
        let h = PKCEHarness(stored: stored())
        h.clock.now = afterExpiry
        h.service.holdNextRefresh()
        h.provider.sceneDidBecomeActive()
        await waitUntil { h.service.refreshCalls.count == 1 }
        h.provider.disconnect()
        h.service.releaseHeld(grant("A2", refresh: "R2"))
        await h.settle()
        #expect(h.store.load() == nil)
        #expect(h.provider.connectionState == .disconnected)
        #expect(h.remote.connectCount == 0)
    }

    @Test("1.0 kaydı (yenileme anahtarı yok) süresi dolunca dokunuşta bir kez web izni ister")
    func legacyRecordMigrates() async {
        let h = PKCEHarness(stored: stored(refresh: nil))
        h.clock.now = afterExpiry
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.service.refreshCalls.isEmpty)

        h.approveInBrowser()
        h.service.setExchange(grant("A1", refresh: "R1"))
        h.provider.connect()
        await h.settle()
        #expect(h.web.urls.count == 1)
        #expect(h.store.load()?.refreshToken == "R1")
    }

    @Test("yeniden deneme zamanlayıcısı süresi dolmuş anahtarı yeniler")
    func retryRefreshes() async {
        let h = PKCEHarness(stored: stored("A1"))
        h.provider.sceneDidBecomeActive()
        h.remote.emitConnectionFailed()
        #expect(h.scheduler.pendingCount == 1)
        h.clock.now = afterExpiry
        h.service.queueRefresh(grant("A2"))
        h.scheduler.fireLatest()
        await h.settle()
        #expect(h.service.refreshCalls == ["R1"])
        #expect(h.remote.tokens.last == "A2")
        #expect(h.remote.connectCount == 2)
    }

    @Test("PKCE kodlu dönüş onOpenURL'e düşerse yok sayılır")
    func codeCallbackIgnoredByOpenURL() {
        let h = PKCEHarness(stored: stored("A1"))
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.handleOpenURL(URL(string: "fokus://spotify-callback?code=x&state=st8")!))
        #expect(h.store.load()?.accessToken == "A1")
        #expect(h.provider.connectionState == .connecting)
    }
}
