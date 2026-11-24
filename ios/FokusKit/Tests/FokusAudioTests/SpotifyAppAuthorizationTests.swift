import Foundation
import Testing

@testable import FokusAudio

/// Spotify uygulamasına geçerek PKCE izni (SDK `SPTSessionManager`). Testte sonuç elle verilir.
@MainActor
final class FakeAppAuthorizer: SpotifyAppAuthorizing {
    private(set) var authorizeCount = 0
    private(set) var handledURLs: [URL] = []
    private(set) var cancelCount = 0
    private var continuation: CheckedContinuation<SpotifyAppAuthResult, Never>?
    /// `handleOpenURL` bu bağlantıyı tanısın mı?
    var recognizesURLs = true

    var isPending: Bool { continuation != nil }

    func authorize() async -> SpotifyAppAuthResult {
        authorizeCount += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        handledURLs.append(url)
        return recognizesURLs
    }

    func cancelPendingAuthorization() {
        cancelCount += 1
        finish(.cancelled)
    }

    func finish(_ result: SpotifyAppAuthResult) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: result)
    }
}

@MainActor
private struct AppAuthHarness {
    let remote = FakeSpotifyRemote()
    let scheduler = FakeSpotifyScheduler()
    let store: InMemorySpotifyTokenStore
    let service = FakeTokenService()
    let web = FakeWebAuthenticator()
    let app = FakeAppAuthorizer()
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
                clientID: "cid", tokenService: service, webAuthenticator: web, appAuthorizer: app))
    }

    func waitForAuthorizeCall() async {
        for _ in 0..<1000 where !app.isPending { await Task.yield() }
    }

    func settle() async {
        for _ in 0..<50 {
            if let task = provider.authTask { await task.value } else { await Task.yield() }
        }
    }
}

private let callback = URL(string: "fokus://spotify-callback?code=c0de&state=s")!

@MainActor
@Suite("SpotifyMusicProvider izin: Spotify uygulaması (PKCE, şifresiz)")
struct SpotifyAppAuthorizationTests {
    @Test("bağlan: web sayfası açılmaz, Spotify uygulamasında izin → yenileme anahtarı kaydedilir → bağlanır")
    func grantedViaSpotifyApp() async {
        let h = AppAuthHarness()
        h.provider.connect()
        await h.waitForAuthorizeCall()

        #expect(h.app.authorizeCount == 1)
        #expect(h.web.urls.isEmpty)
        #expect(h.provider.connectionState == .connecting)

        // Spotify'a geçiş ve dönüş: sahne etkisizleşir, dönüş bağlantısı SDK'ya iletilir.
        h.provider.sceneWillResignActive()
        #expect(h.provider.handleOpenURL(callback))
        #expect(h.app.handledURLs == [callback])
        h.provider.sceneDidBecomeActive()
        h.app.finish(.granted(SpotifyTokenGrant(accessToken: "A1", expiresIn: 3600, refreshToken: "R1")))
        await h.settle()

        #expect(h.store.load()?.accessToken == "A1")
        #expect(h.store.load()?.refreshToken == "R1")
        #expect(h.remote.tokens.last == "A1")
        #expect(h.remote.connectCount == 1)
        #expect(h.remote.authorizeCount == 0)
        #expect(h.app.cancelCount == 0)
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("dönüş bağlantısı gelmeden Fokus'a dönülürse bekleme süresi sonunda izin iptal sayılır")
    func returnWithoutCallbackCancels() async {
        let h = AppAuthHarness()
        h.provider.connect()
        await h.waitForAuthorizeCall()

        h.provider.sceneWillResignActive()
        h.provider.sceneDidBecomeActive()
        #expect(h.scheduler.pendingCount == 1)
        h.scheduler.fireLatest()
        await h.settle()

        #expect(h.app.cancelCount == 1)
        #expect(h.provider.connectionState == .failed(.authorizationDenied))
        #expect(h.store.load() == nil)
        #expect(h.remote.connectCount == 0)
    }

    @Test("dönüş bağlantısı geldiyse (anahtar değişimi sürerken) bekleme süresi izni iptal etmez")
    func callbackPreventsCancel() async {
        let h = AppAuthHarness()
        h.provider.connect()
        await h.waitForAuthorizeCall()

        h.provider.sceneWillResignActive()
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.handleOpenURL(callback))
        h.scheduler.fireLatest()
        #expect(h.app.cancelCount == 0)

        h.app.finish(.granted(SpotifyTokenGrant(accessToken: "A1", expiresIn: 3600, refreshToken: "R1")))
        await h.settle()
        #expect(h.remote.connectCount == 1)
    }

    @Test("Spotify izni reddederse ya da açılamazsa anahtar kaydedilmez")
    func failures() async {
        let denied = AppAuthHarness()
        denied.provider.connect()
        await denied.waitForAuthorizeCall()
        denied.app.finish(.cancelled)
        await denied.settle()
        #expect(denied.provider.connectionState == .failed(.authorizationDenied))

        let failed = AppAuthHarness()
        failed.provider.connect()
        await failed.waitForAuthorizeCall()
        failed.app.finish(.failed)
        await failed.settle()
        #expect(failed.provider.connectionState == .failed(.unknown))
        #expect(failed.store.load() == nil)
    }

    @Test("izin sürerken bağlantı kesilirse sonuç yok sayılır")
    func disconnectDuringAuthorization() async {
        let h = AppAuthHarness()
        h.provider.connect()
        await h.waitForAuthorizeCall()
        h.provider.disconnect()
        h.app.finish(.granted(SpotifyTokenGrant(accessToken: "A1", expiresIn: 3600, refreshToken: "R1")))
        await h.settle()
        #expect(h.store.load() == nil)
        #expect(h.provider.connectionState == .disconnected)
        #expect(h.remote.connectCount == 0)
    }

    @Test("izin yokken gelen kodlu bağlantı SDK'ya iletilmez")
    func codeURLIgnoredWhenNotAuthorizing() {
        let h = AppAuthHarness(stored: SpotifyTokenRecord(accessToken: "A1", issuedAt: testEpoch, refreshToken: "R1"))
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.handleOpenURL(callback))
        #expect(h.app.handledURLs.isEmpty)
    }

    @Test("süresi dolmuş anahtar: öne gelişte izin sayfası değil sessiz yenileme")
    func expiredTokenRefreshesInsteadOfReauthorizing() async {
        let h = AppAuthHarness(stored: SpotifyTokenRecord(accessToken: "old", issuedAt: testEpoch, refreshToken: "R1"))
        h.clock.now = testEpoch.addingTimeInterval(4000)
        h.service.queueRefresh(.success(SpotifyTokenGrant(accessToken: "A2", expiresIn: 3600, refreshToken: nil)))
        h.provider.sceneDidBecomeActive()
        await h.settle()
        #expect(h.app.authorizeCount == 0)
        #expect(h.remote.tokens.last == "A2")
        #expect(h.store.load()?.refreshToken == "R1")
    }
}
