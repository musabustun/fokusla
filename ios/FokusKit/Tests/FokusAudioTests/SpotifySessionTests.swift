import Foundation
import Testing

@testable import FokusAudio

// MARK: - Sahteler

@MainActor
final class FakeSpotifyRemote: SpotifyRemoteControlling {
    var isConnected = false
    var onEvent: (@MainActor (SpotifyRemoteEvent) -> Void)?
    private(set) var tokens: [String?] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var authorizeCount = 0
    private(set) var subscribeCount = 0
    private(set) var commands: [SpotifyRemoteCommand] = []
    var authorizeResult = true
    var commandFailure: SpotifyRemoteFailure?

    func setAccessToken(_ token: String?) { tokens.append(token) }
    func connect() { connectCount += 1 }
    func disconnect() {
        disconnectCount += 1
        isConnected = false
    }
    func authorize(completion: @escaping @MainActor (Bool) -> Void) {
        authorizeCount += 1
        completion(authorizeResult)
    }
    func authorizationParameters(from url: URL) -> [String: String]? { nil }
    func subscribeToPlayerState() { subscribeCount += 1 }
    func send(_ command: SpotifyRemoteCommand, completion: @escaping @MainActor (SpotifyRemoteFailure?) -> Void) {
        commands.append(command)
        completion(commandFailure)
    }
    func fetchArtwork(identifier: String, size: CGSize, completion: @escaping @MainActor (Data?) -> Void) {
        completion(Data([1, 2, 3]))
    }

    /// SDK'nın bağlantıyı kurduğunu taklit eder.
    func emitConnected() {
        isConnected = true
        onEvent?(.connected)
    }
    func emitConnectionFailed(code: Int = SpotifyRemoteErrorCode.connectionAttemptFailed, text: String = "") {
        isConnected = false
        onEvent?(.connectionFailed(SpotifyRemoteFailure(code: code, description: text)))
    }
    func emitDisconnected() {
        isConnected = false
        onEvent?(
            .disconnected(SpotifyRemoteFailure(code: SpotifyRemoteErrorCode.connectionTerminated, description: "")))
    }
    func emitPlayer(title: String = "T", paused: Bool = false) {
        onEvent?(
            .playerState(SpotifyPlayerSnapshot(title: title, artist: "A", isPaused: paused, imageIdentifier: "img")))
    }
}

@MainActor
final class FakeSpotifyScheduler: SpotifyScheduling {
    struct Entry {
        var delay: Duration
        var work: @MainActor () -> Void
        var isCancelled = false
    }
    private(set) var entries: [Entry] = []

    var delays: [Duration] { entries.filter { !$0.isCancelled }.map(\.delay) }
    var pendingCount: Int { entries.filter { !$0.isCancelled }.count }

    func schedule(after delay: Duration, _ work: @escaping @MainActor () -> Void) -> SpotifyScheduledWork {
        let index = entries.count
        entries.append(Entry(delay: delay, work: work))
        return SpotifyScheduledWork { [weak self] in self?.entries[index].isCancelled = true }
    }

    /// En son zamanlanan, iptal edilmemiş işi çalıştırır.
    func fireLatest() {
        guard let index = entries.lastIndex(where: { !$0.isCancelled }) else { return }
        entries[index].isCancelled = true
        entries[index].work()
    }
}

/// Testlerin ortak "şimdi"si.
let testEpoch = Date(timeIntervalSince1970: 1_000_000)

func makeToken(_ value: String = "tok", issuedAt: Date = testEpoch) -> SpotifyTokenRecord {
    SpotifyTokenRecord(accessToken: value, issuedAt: issuedAt)
}

@MainActor final class InstalledFlag { var value = true }

@MainActor
struct Harness {
    let remote: FakeSpotifyRemote
    let scheduler: FakeSpotifyScheduler
    let store: InMemorySpotifyTokenStore
    let provider: SpotifyMusicProvider
    var callback: URL { URL(string: "fokus://spotify-callback#access_token=newtok")! }

    init(stored: SpotifyTokenRecord? = nil, installed: Bool = true, configured: Bool = true) {
        let remote = FakeSpotifyRemote()
        let scheduler = FakeSpotifyScheduler()
        let store = InMemorySpotifyTokenStore(stored)
        self.remote = remote
        self.scheduler = scheduler
        self.store = store
        self.provider = SpotifyMusicProvider(
            remote: configured ? remote : nil, tokenStore: store, canOpenURL: { _ in installed },
            now: { testEpoch }, scheduler: scheduler)
    }
}

// MARK: - Token

@Suite("SpotifyTokenRecord")
struct SpotifyTokenRecordTests {
    @Test(
        "geçerlilik: sona erme payı, süresi dolmuş ve geri alınmış saat",
        arguments: [
            (0.0, SpotifyConnectionPolicy.TokenState.valid),
            (1000.0, .valid),
            (3600.0 - 121.0, .valid),
            (3600.0 - 119.0, .expired),
            (3600.0, .expired),
            (7200.0, .expired),
            (-4000.0, .expired),  // saat geri alındı: kalan süre ömürden büyük
        ])
    func state(elapsed: Double, expected: SpotifyConnectionPolicy.TokenState) {
        #expect(makeToken().state(at: testEpoch.addingTimeInterval(elapsed)) == expected)
    }

    @Test("boş token 'missing' sayılır")
    func emptyToken() {
        #expect(makeToken("").state(at: testEpoch) == .missing)
    }

    @Test("JSON gidiş-dönüş ve bellek içi depo")
    func codableAndStore() throws {
        let record = makeToken("abc")
        let decoded = try JSONDecoder().decode(SpotifyTokenRecord.self, from: JSONEncoder().encode(record))
        #expect(decoded == record)

        let store = InMemorySpotifyTokenStore()
        #expect(store.load() == nil)
        #expect(store.save(record))
        #expect(store.load() == record)
        store.clear()
        #expect(store.load() == nil)
    }
}

/// Keychain her test ortamında (ör. ana uygulamasız simülatör test paketi) yazılabilir değildir; yoksa atlanır.
enum KeychainProbe {
    static let isAvailable: Bool = {
        let store = KeychainSpotifyTokenStore(service: "com.musabustun.fokus.tests.probe.\(UUID().uuidString)")
        defer { store.clear() }
        return store.save(makeToken("p"))
    }()
}

@Suite("KeychainSpotifyTokenStore", .enabled(if: KeychainProbe.isAvailable))
struct KeychainSpotifyTokenStoreTests {
    @Test("yaz, oku, üzerine yaz, sil")
    func roundTrip() {
        let store = KeychainSpotifyTokenStore(service: "com.musabustun.fokus.tests.\(UUID().uuidString)")
        defer { store.clear() }
        let first = makeToken("one")
        let second = makeToken("two", issuedAt: testEpoch.addingTimeInterval(100))
        #expect(store.load() == nil)
        #expect(store.save(first))
        #expect(store.load() == first)
        #expect(store.save(second))
        #expect(store.load() == second)
        store.clear()
        #expect(store.load() == nil)
    }
}

// MARK: - Politika

@Suite("SpotifyConnectionPolicy yeniden bağlanma")
struct SpotifyReconnectPolicyTests {
    @Test(
        "üstel bekleme 0,5 → 1 → 2 → 4 → 8 sn ve üst sınır",
        arguments: [
            (1, Duration.milliseconds(500)), (2, .seconds(1)), (3, .seconds(2)), (4, .seconds(4)),
            (5, .seconds(8)), (6, .seconds(8)), (40, .seconds(8)),
        ])
    func backoff(attempt: Int, expected: Duration) {
        #expect(SpotifyConnectionPolicy.backoffDelay(afterFailedAttempt: attempt) == expected)
    }

    @Test(
        "öne gelince eylem",
        arguments: [
            (true, SpotifyConnectionPolicy.TokenState.valid, false, false, SpotifyConnectionPolicy.ActivationAction.silentConnect),
            (true, .expired, false, false, .needsReconnect),
            (true, .missing, false, false, .needsReconnect),
            (true, .valid, true, false, .none),
            (true, .valid, false, true, .none),
            (false, .valid, false, false, .none),
        ])
    func activation(
        wants: Bool, token: SpotifyConnectionPolicy.TokenState, connected: Bool, inFlight: Bool,
        expected: SpotifyConnectionPolicy.ActivationAction
    ) {
        #expect(
            SpotifyConnectionPolicy.activationAction(
                wantsConnection: wants, tokenState: token, isConnected: connected, isAttemptInFlight: inFlight)
                == expected)
    }

    @Test(
        "başarısızlıktan sonra eylem",
        arguments: [
            (true, false, 0, SpotifyConnectionPolicy.ConnectionFailureAction.reauthorize),
            (true, true, 0, .fail),
            (false, false, 1, .retry(after: .milliseconds(500))),
            (false, false, 4, .retry(after: .seconds(4))),
            (false, false, 5, .fail),
            (false, true, 9, .fail),
        ])
    func failure(
        user: Bool, reauthorized: Bool, attempts: Int, expected: SpotifyConnectionPolicy.ConnectionFailureAction
    ) {
        #expect(
            SpotifyConnectionPolicy.actionAfterConnectionFailure(
                isUserInitiated: user, alreadyReauthorized: reauthorized, failedAttempts: attempts)
                == expected)
    }
}

// MARK: - Durum makinesi

@MainActor
@Suite("SpotifyMusicProvider durum makinesi")
struct SpotifyProviderStateMachineTests {
    @Test("Client ID yoksa gizlenir; SDK ve depoya dokunulmaz")
    func notConfigured() {
        let h = Harness(configured: false)
        #expect(h.provider.availability == .notConfigured)
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.connectionState == .disconnected)
        #expect(h.remote.connectCount == 0 && h.remote.authorizeCount == 0)
    }

    @Test("ilk bağlanma: yetkilendir → geri dönüş → token Keychain'e yazılır → bağlan → bağlı")
    func firstConnect() {
        let h = Harness()
        h.provider.connect()
        #expect(h.remote.authorizeCount == 1)
        #expect(h.provider.connectionState == .connecting)

        #expect(h.provider.handleOpenURL(h.callback))
        let saved = h.store.load()
        #expect(saved?.accessToken == "newtok")
        #expect(saved?.expiresAt == testEpoch.addingTimeInterval(SpotifyTokenRecord.defaultLifetime))
        #expect(h.remote.tokens.last == "newtok")
        #expect(h.remote.connectCount == 1)

        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
        #expect(h.remote.subscribeCount == 1)
        #expect(!h.provider.isReconnecting)
    }

    @Test("çalan parça ve kapak aktarılır")
    func nowPlaying() {
        let h = Harness()
        h.provider.connect()
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnected()
        h.remote.emitPlayer()
        #expect(
            h.provider.nowPlaying
                == MusicTrack(title: "T", artist: "A", artworkData: Data([1, 2, 3]), isPaused: false))
        #expect(h.provider.nowPlaying?.isPlaying == true)
    }

    @Test("uygulama yeniden başlayınca kayıtlı geçerli token ile sessiz bağlanır (yetkilendirme yok)")
    func relaunchWithValidToken() {
        let h = Harness(stored: makeToken("kept"))
        #expect(h.provider.connectionState == .connecting)  // düğme titremez
        h.provider.sceneDidBecomeActive()
        #expect(h.remote.authorizeCount == 0)
        #expect(h.remote.tokens.last == "kept")
        #expect(h.remote.connectCount == 1)
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("kayıtlı token'ın süresi dolmuşsa Spotify'a yönlendirmeden 'Yeniden bağlan' gösterilir")
    func relaunchWithExpiredToken() {
        let h = Harness(stored: makeToken("old", issuedAt: testEpoch.addingTimeInterval(-7200)))
        h.provider.sceneDidBecomeActive()
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.remote.authorizeCount == 0 && h.remote.connectCount == 0)
        #expect(h.store.load() != nil)  // kayıt korunur
        h.provider.connect()  // kullanıcı dokunur → yetkilendirme (kullanıcı eylemi)
        #expect(h.remote.authorizeCount == 1)
    }

    @Test("arka plana geçiş kopma sayılmaz: durum bağlı kalır, dönüşte sessiz yeniden bağlanır")
    func backgroundIsNotADisconnect() {
        let h = Harness()
        h.provider.connect()
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnected()
        h.remote.emitPlayer()

        h.provider.sceneWillResignActive()
        #expect(h.remote.disconnectCount == 1)
        h.remote.emitDisconnected()  // bilerek kestiğimiz bağlantının SDK bildirimi
        #expect(h.provider.connectionState == .connected)
        #expect(h.provider.nowPlaying?.title == "T")
        #expect(h.store.load() != nil)

        h.provider.sceneDidBecomeActive()
        #expect(h.remote.connectCount == 2)
        #expect(h.remote.authorizeCount == 1)  // Spotify'a yeniden gidilmedi
        #expect(h.provider.isReconnecting)
        #expect(h.provider.connectionState == .connected)
        h.remote.emitConnected()
        #expect(!h.provider.isReconnecting)
        #expect(h.provider.connectionState == .connected)
    }

    @Test("sessiz yeniden bağlanma başarısızsa üstel beklemeyle 5 deneme, sonra 'Yeniden bağlan'; token korunur")
    func exponentialBackoffThenRecoverable() {
        let h = Harness(stored: makeToken())
        h.provider.sceneDidBecomeActive()
        #expect(h.remote.connectCount == 1)

        var observed: [Duration] = []
        for attempt in 1...4 {
            h.remote.emitConnectionFailed()
            observed.append(h.scheduler.delays.last ?? .zero)
            #expect(h.provider.isReconnecting)
            h.scheduler.fireLatest()
            #expect(h.remote.connectCount == attempt + 1)
        }
        #expect(observed == [.milliseconds(500), .seconds(1), .seconds(2), .seconds(4)])

        h.remote.emitConnectionFailed()  // 5. başarısızlık
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.scheduler.pendingCount == 0)
        #expect(!h.provider.isReconnecting)
        #expect(h.remote.authorizeCount == 0)  // hiç Spotify'a yönlendirilmedi
        #expect(h.store.load() != nil)

        // Bir sonraki öne gelişte (token hâlâ geçerli) yeniden sessizce denenir.
        h.provider.sceneDidBecomeActive()
        #expect(h.remote.connectCount == 6)
        h.remote.emitConnected()
        #expect(h.provider.connectionState == .connected)
    }

    @Test("yeniden deneme zamanlayıcısı arka plana geçince iptal edilir; dönüşte yeniden başlar")
    func retryCancelledWhenBackgrounded() {
        let h = Harness(stored: makeToken())
        h.provider.sceneDidBecomeActive()
        h.remote.emitConnectionFailed()
        #expect(h.scheduler.pendingCount == 1)
        h.provider.sceneWillResignActive()
        #expect(h.scheduler.pendingCount == 0)
        h.provider.sceneDidBecomeActive()
        #expect(h.remote.connectCount == 2)
    }

    @Test("kullanıcı başlatan denemede token reddedilirse bir kez yeniden yetkilendirilir, sonra kalıcı hata")
    func userAttemptReauthorizesOnce() {
        let h = Harness(stored: makeToken("stale"))
        h.provider.sceneDidBecomeActive()
        for _ in 0..<5 {  // otomatik denemeler tükenir
            h.remote.emitConnectionFailed()
            h.scheduler.fireLatest()
        }
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.remote.authorizeCount == 0)

        h.provider.connect()  // kullanıcı dokundu: geçerli görünen token ile sessiz deneme
        #expect(h.remote.authorizeCount == 0)
        h.remote.emitConnectionFailed()
        #expect(h.remote.authorizeCount == 1)  // token reddedildi → bir kez yetkilendir
        #expect(h.store.load() == nil)
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnectionFailed()  // taze token'la da olmadı
        #expect(h.provider.connectionState == .failed(.connectionLost))
        #expect(h.store.load() == nil)  // kalıcı hata: kayıt silindi
        #expect(h.remote.authorizeCount == 1)
    }

    @Test("beklenmedik kopma ön plandayken sessizce yeniden bağlanır")
    func unexpectedDisconnect() {
        let h = Harness()
        h.provider.connect()
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnected()
        h.remote.emitDisconnected()
        #expect(h.provider.connectionState == .connected)
        #expect(h.provider.isReconnecting)
        #expect(h.remote.connectCount == 2)
        h.remote.emitConnected()
        #expect(!h.provider.isReconnecting)
    }

    @Test("Bağlantıyı kes token'ı siler ve çalmayı durdurmaz")
    func disconnectClearsToken() {
        let h = Harness()
        h.provider.connect()
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnected()
        h.provider.disconnect()
        #expect(h.store.load() == nil)
        #expect(h.provider.connectionState == .disconnected)
        #expect(h.remote.tokens.last == .some(nil))
        #expect(h.remote.commands.isEmpty)  // pause komutu gönderilmedi
        h.provider.sceneDidBecomeActive()  // artık kendiliğinden bağlanmaz
        #expect(h.remote.connectCount == 1)
    }

    @Test("Premium hatası kalıcıdır ve yeniden denenmez")
    func premiumFailureIsTerminal() {
        let h = Harness(stored: makeToken())
        h.provider.sceneDidBecomeActive()
        h.remote.emitConnectionFailed(code: -2001, text: "Premium required")
        #expect(h.provider.connectionState == .failed(.premiumRequired))
        #expect(h.scheduler.pendingCount == 0)
        #expect(h.store.load() == nil)
    }

    @Test("yetkilendirme reddi, geri dönüşün gelmemesi ve yüklü olmayan Spotify")
    func authorizationOutcomes() {
        let denied = Harness()
        denied.provider.connect()
        _ = denied.provider.handleOpenURL(URL(string: "fokus://spotify-callback?error=access_denied")!)
        #expect(denied.provider.connectionState == .failed(.authorizationDenied))

        let silent = Harness()
        silent.provider.connect()
        silent.provider.sceneDidBecomeActive()  // Spotify'dan dönüldü ama URL gelmedi
        #expect(silent.scheduler.pendingCount == 1)
        silent.scheduler.fireLatest()
        #expect(silent.provider.connectionState == .failed(.authorizationDenied))

        #expect(Harness(installed: false).provider.availability == .appNotInstalled)
    }

    @Test("sessiz yeniden bağlanırken komutlar yoksayılır; Premium komut hatası bağlantıyı düşürmez")
    func commands() {
        let h = Harness()
        h.provider.connect()
        _ = h.provider.handleOpenURL(h.callback)
        h.remote.emitConnected()
        h.remote.emitPlayer(paused: true)
        h.provider.togglePlayPause()
        #expect(h.remote.commands == [.resume])

        h.remote.commandFailure = SpotifyRemoteFailure(code: -2001, description: "Premium required")
        h.provider.skipToNext()
        #expect(h.provider.lastCommandError == .premiumRequired)
        #expect(h.provider.connectionState == .connected)

        h.provider.sceneWillResignActive()
        h.provider.sceneDidBecomeActive()  // yeniden bağlanıyor
        let before = h.remote.commands.count
        h.provider.skipToPrevious()
        #expect(h.remote.commands.count == before)
        #expect(h.provider.connectionState == .connected)
    }

    @Test("Spotify kaldırılırsa durum ve token temizlenir")
    func uninstalled() {
        let store = InMemorySpotifyTokenStore(makeToken())
        let installed = InstalledFlag()
        let provider = SpotifyMusicProvider(
            remote: FakeSpotifyRemote(), tokenStore: store, canOpenURL: { _ in installed.value },
            now: { testEpoch }, scheduler: FakeSpotifyScheduler())
        installed.value = false
        provider.sceneDidBecomeActive()
        #expect(provider.availability == .appNotInstalled)
        #expect(provider.connectionState == .disconnected)
        #expect(store.load() == nil)
    }
}
