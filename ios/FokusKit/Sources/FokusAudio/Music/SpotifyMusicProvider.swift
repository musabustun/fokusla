import Foundation
import Observation
import OSLog

/// Spotify App Remote üzerinden isteğe bağlı müzik denetimi; bağlantı durum makinesi burada, SDK
/// `SpotifyRemoteControlling` arkasındadır (testlerde sahtelenir).
///
/// Kalıcılık ilkeleri:
/// - İlk bağlanışta (Client ID varsa) Spotify'ın "Authorization Code with PKCE" akışı uygulama içi web sayfasında
///   bir kez yapılır; erişim + YENİLEME anahtarı Keychain'de (`SpotifyTokenStoring`) saklanır. Uygulama yeniden
///   başlayınca kayıt varsa kullanıcı "bağlı kalmak istiyor" sayılır.
/// - Öne gelince erişim anahtarı geçerliyse sessizce bağlanılır; süresi dolmuşsa yenileme anahtarıyla
///   (`accounts.spotify.com/api/token`, yalnızca `client_id`) sessizce yenilenip bağlanılır. Kullanıcı Spotify'da
///   erişimi kaldırmadıkça (`invalid_grant`) bir daha izin sayfası görmez. Yenileme yoksa Spotify'a
///   YÖNLENDİRİLMEDEN "Yeniden bağlan" durumu (`failed(.connectionLost)`) gösterilir.
/// - Spotify uygulaması çalışmıyorsa App Remote sessizce bağlanamaz; kullanıcı dokununca Spotify
///   `authorizeAndPlayURI("")` ile uyandırılır (yenileme anahtarı korunur).
/// - Arka plana geçerken SDK bağlantısını bilerek kesmek "kopma" değildir: durum `connected` kalır, dönüşte
///   otomatik yeniden bağlanılır. Beklenmedik kopma/başarısız denemede üstel beklemeyle sınırlı sayıda
///   sessiz tekrar yapılır.
/// - Yalnızca çalma için gerekenler okunur: parça adı, sanatçı, kapak, çalma durumu. Ad/fotoğraf/e-posta
///   istenmez; yetki yalnızca `app-remote-control`'dür; Web API ve Client Secret kullanılmaz.
@MainActor
@Observable
public final class SpotifyMusicProvider: MusicProvider {
    /// Spotify Developer Dashboard'daki redirect URI ile BİREBİR aynı olmalı (xcconfig'e konmaz: `//`
    /// xcconfig'te yorum başlatır).
    public static let redirectURL = URL(string: "fokus://spotify-callback")!

    private static let artworkSize = CGSize(width: 600, height: 600)
    /// Yetkilendirmeden dönüşte `onOpenURL` gecikirse beklenen süre; dolunca iptal sayılır.
    private static let authorizationGrace: Duration = .seconds(2)

    public let id: MusicProviderID = .spotify
    public let displayName = "Spotify"
    public let appURL = URL(string: "spotify:")!
    public let webURL = URL(string: "https://open.spotify.com")!
    public private(set) var availability: MusicProviderAvailability
    public private(set) var connectionState: MusicConnectionState = .disconnected
    public private(set) var nowPlaying: MusicTrack?
    public private(set) var lastCommandError: MusicProviderError?
    public private(set) var isReconnecting = false

    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.musabustun.fokus", category: "focus-spotify")
    @ObservationIgnored private let remote: (any SpotifyRemoteControlling)?
    @ObservationIgnored private let tokenStore: any SpotifyTokenStoring
    @ObservationIgnored private let canOpenURL: @MainActor (URL) -> Bool
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let scheduler: any SpotifyScheduling
    @ObservationIgnored private let pkce: SpotifyPKCEAuthorization?

    @ObservationIgnored private var token: SpotifyTokenRecord?
    /// Kullanıcı bağlı kalmak istiyor (bağlan'a bastı / kayıtlı token var, bağlantıyı kesmedi).
    @ObservationIgnored private var wantsConnection = false
    @ObservationIgnored private var awaitingAuthorization = false
    @ObservationIgnored private var isAttemptInFlight = false
    @ObservationIgnored private var isUserInitiatedAttempt = false
    @ObservationIgnored private var hasReauthorized = false
    /// Arka plana geçerken SDK bağlantısını bilerek kestik; `didDisconnect` hata sayılmaz.
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var failedAutomaticAttempts = 0
    @ObservationIgnored private var retryWork: SpotifyScheduledWork?
    @ObservationIgnored private var graceWork: SpotifyScheduledWork?
    @ObservationIgnored private var artworkImageID: String?
    @ObservationIgnored private var artworkData: Data?
    /// Uygulama içi web yetkilendirmesi (ve kod → anahtar değişimi) sürüyor.
    @ObservationIgnored private var isWebAuthorizing = false
    /// Yenileme isteği sürüyor (arka plana geçişte de korunur: aynı anahtarla ikinci istek atılmasın).
    @ObservationIgnored private var isRefreshing = false
    /// Kullanıcı bağlantıyı kesince artar; eski ağ işlerinin sonucu yok sayılır.
    @ObservationIgnored private var authGeneration = 0
    @ObservationIgnored var authTask: Task<Void, Never>?

    /// `remote == nil` ise (Client ID boş) entegrasyon gizlenir ve hiçbir SDK nesnesi/depo kullanılmaz.
    public init(
        remote: (any SpotifyRemoteControlling)?,
        tokenStore: any SpotifyTokenStoring = InMemorySpotifyTokenStore(),
        canOpenURL: @escaping @MainActor (URL) -> Bool,
        now: @escaping @MainActor () -> Date = { Date() },
        scheduler: any SpotifyScheduling = TaskSpotifyScheduler(),
        pkce: SpotifyPKCEAuthorization? = nil
    ) {
        self.remote = remote
        self.tokenStore = tokenStore
        self.canOpenURL = canOpenURL
        self.now = now
        self.scheduler = scheduler
        self.pkce = pkce
        guard let remote else {
            availability = .notConfigured
            return
        }
        availability = canOpenURL(URL(string: "spotify:")!) ? .available : .appNotInstalled
        remote.onEvent = { [weak self] event in self?.handle(event) }
        if let stored = tokenStore.load() {
            if availability == .available {
                token = stored
                wantsConnection = true
                // Öne gelme olayı (`sceneDidBecomeActive`) bağlanmayı başlatır; o ana kadar "bağlan" düğmesi titremesin.
                connectionState = .connecting
                isReconnecting = true
            } else {
                tokenStore.clear()
            }
        }
    }

    // MARK: - MusicProvider

    public func connect() {
        refreshAvailability()
        guard let remote, availability == .available else {
            connectionState = .failed(availability == .notConfigured ? .notConfigured : .appNotInstalled)
            return
        }
        guard connectionState != .connected, connectionState != .connecting else { return }
        wantsConnection = true
        isUserInitiatedAttempt = true
        hasReauthorized = false
        failedAutomaticAttempts = 0
        lastCommandError = nil
        connectionState = .connecting
        if validToken() != nil {
            startSilentConnect(remote)
        } else if let refreshToken = refreshableToken() {
            startRefresh(remote, refreshToken: refreshToken)
        } else {
            startAuthorization(remote)
        }
    }

    /// Kullanıcının isteğiyle keser ve token'ı siler; Spotify çalmaya devam eder (durdurma komutu gönderilmez).
    public func disconnect() {
        wantsConnection = false
        awaitingAuthorization = false
        isAttemptInFlight = false
        isSuspended = false
        cancelScheduledWork()
        invalidateAuthWork()
        clearToken()
        remote?.setAccessToken(nil)
        remote?.disconnect()
        resetPlaybackState()
        isReconnecting = false
        connectionState = .disconnected
    }

    public func togglePlayPause() {
        let isPaused = nowPlaying?.isPaused ?? false
        send(isPaused ? .resume : .pause)
    }

    public func skipToNext() { send(.skipToNext) }

    public func skipToPrevious() { send(.skipToPrevious) }

    public func handleOpenURL(_ url: URL) -> Bool {
        guard SpotifyAuthCallback.matches(url, redirect: Self.redirectURL) else { return false }
        guard let remote else { return true }
        // PKCE dönüşünü `ASWebAuthenticationSession` yakalar; buraya düşen kodlu bağlantı yok sayılır.
        let rawParameters = SpotifyAuthCallback.parameters(from: url)
        guard !isWebAuthorizing, rawParameters["code"] == nil || rawParameters["access_token"] != nil else {
            return true
        }
        awaitingAuthorization = false
        graceWork?.cancel()
        guard wantsConnection else { return true }

        let parameters = remote.authorizationParameters(from: url) ?? rawParameters
        switch SpotifyAuthCallback.interpret(parameters) {
        case .token(let accessToken):
            // Uyandırma dönüşü: yalnızca erişim anahtarı yenilenir, yenileme anahtarı korunur.
            storeToken(
                SpotifyTokenRecord(accessToken: accessToken, issuedAt: now(), refreshToken: token?.refreshToken))
            startSilentConnect(remote)
        case .failure(let error):
            logger.error("Yetkilendirme tamamlanmadı: \(String(describing: error), privacy: .public)")
            if error != .authorizationDenied, token?.canRefresh == true {
                failRecoverable(error)
            } else {
                failTerminal(error)
            }
        }
        return true
    }

    public func sceneDidBecomeActive() {
        refreshAvailability()
        guard availability == .available, let remote else { return }
        // Web yetkilendirme sayfası açılıp kapanırken sahne etkin/etkisiz olur; sonuç oturumdan gelir.
        guard !isWebAuthorizing else { return }
        if awaitingAuthorization {
            scheduleAuthorizationGrace()
            return
        }
        isSuspended = false
        let action = SpotifyConnectionPolicy.activationAction(
            wantsConnection: wantsConnection, tokenState: tokenState(), canRefresh: refreshableToken() != nil,
            isConnected: remote.isConnected, isAttemptInFlight: isAttemptInFlight || isRefreshing)
        switch action {
        case .none:
            // Bağlantı sağlam ya da deneme sürüyor; bekleyen yeniden deneme zamanlayıcısı varsa bırak.
            if remote.isConnected, wantsConnection, connectionState != .connected { markConnected() }
        case .silentConnect:
            beginAutomaticConnect(remote)
        case .refreshThenConnect:
            guard let refreshToken = refreshableToken() else { return }
            beginAutomaticRefresh(remote, refreshToken: refreshToken)
        case .needsReconnect:
            logger.info("Spotify token'ı yok/süresi dolmuş; 'Yeniden bağlan' durumu gösteriliyor.")
            failRecoverable()
        }
    }

    /// SDK önerisi: ön planda değilken bağlantıyı kes. Kullanıcı bağlı kalmak istiyorsa durum ve çalan
    /// parça korunur (titreme olmasın); öne dönünce sessizce yeniden bağlanılır.
    public func sceneWillResignActive() {
        graceWork?.cancel()
        guard !awaitingAuthorization, !isWebAuthorizing, let remote, wantsConnection else { return }
        guard remote.isConnected || isAttemptInFlight || isRefreshing || retryWork != nil else { return }
        retryWork?.cancel()
        retryWork = nil
        isSuspended = true
        isAttemptInFlight = false
        remote.disconnect()
    }

    // MARK: - Bağlantı

    private func tokenState() -> SpotifyConnectionPolicy.TokenState {
        token?.state(at: now()) ?? .missing
    }

    private func validToken() -> SpotifyTokenRecord? {
        tokenState() == .valid ? token : nil
    }

    /// Yenileme yapılabiliyorsa (PKCE yapılandırılmış ve kayıtta yenileme anahtarı var) anahtar.
    private func refreshableToken() -> String? {
        pkce == nil ? nil : token?.refreshToken
    }

    private func storeToken(_ record: SpotifyTokenRecord) {
        token = record
        if !tokenStore.save(record) { logger.error("Spotify token'ı Keychain'e yazılamadı.") }
    }

    private func clearToken() {
        token = nil
        tokenStore.clear()
    }

    /// Süren web yetkilendirmesi/yenileme sonuçlarını geçersiz kılar.
    private func invalidateAuthWork() {
        authGeneration += 1
        authTask?.cancel()
        authTask = nil
        isWebAuthorizing = false
        isRefreshing = false
    }

    private func refreshAvailability() {
        guard let remote else { return }
        let updated: MusicProviderAvailability = canOpenURL(appURL) ? .available : .appNotInstalled
        guard updated != availability else { return }
        availability = updated
        if updated != .available, connectionState != .disconnected {
            remote.disconnect()
            wantsConnection = false
            cancelScheduledWork()
            invalidateAuthWork()
            clearToken()
            resetPlaybackState()
            isReconnecting = false
            connectionState = .disconnected
        }
    }

    /// Yeni izin: PKCE yapılandırılmışsa uygulama içi web sayfası (yenileme anahtarı verir), değilse
    /// App Remote yetkilendirmesi (yalnızca 1 saatlik anahtar).
    private func startAuthorization(_ remote: any SpotifyRemoteControlling) {
        if pkce != nil {
            startWebAuthorization()
        } else {
            startAppRemoteAuthorization(remote)
        }
    }

    /// Spotify'a gidip izin ister (yalnızca `app-remote-control`); Spotify çalışmıyorsa uyandırır.
    private func startAppRemoteAuthorization(_ remote: any SpotifyRemoteControlling) {
        awaitingAuthorization = true
        remote.authorize { [weak self] success in
            guard !success, let self else { return }
            self.awaitingAuthorization = false
            self.refreshAvailability()
            self.failTerminal(.appNotInstalled)
        }
    }

    private func startSilentConnect(_ remote: any SpotifyRemoteControlling) {
        remote.setAccessToken(token?.accessToken)
        isAttemptInFlight = true
        if connectionState != .connected { connectionState = .connecting }
        remote.connect()
    }

    /// Kullanıcı dokunmadan yeniden bağlanma (öne dönüş, beklenmedik kopma).
    private func beginAutomaticConnect(_ remote: any SpotifyRemoteControlling) {
        retryWork?.cancel()
        retryWork = nil
        isUserInitiatedAttempt = false
        failedAutomaticAttempts = 0
        isReconnecting = true
        startSilentConnect(remote)
    }

    private func scheduleAuthorizationGrace() {
        graceWork?.cancel()
        graceWork = scheduler.schedule(after: Self.authorizationGrace) { [weak self] in
            guard let self, self.awaitingAuthorization else { return }
            self.awaitingAuthorization = false
            self.logger.info("Yetkilendirmeden geri dönüş bağlantısı gelmedi; iptal sayıldı.")
            if self.token?.canRefresh == true {
                self.failRecoverable()
            } else {
                self.failTerminal(.authorizationDenied)
            }
        }
    }

    private func scheduleRetry(after delay: Duration) {
        retryWork?.cancel()
        isReconnecting = true
        retryWork = scheduler.schedule(after: delay) { [weak self] in
            guard let self, let remote = self.remote else { return }
            self.retryWork = nil
            guard self.wantsConnection, !self.isSuspended, !self.awaitingAuthorization,
                !self.isAttemptInFlight, !remote.isConnected
            else { return }
            guard !self.isRefreshing else { return }
            guard self.validToken() != nil else {
                if let refreshToken = self.refreshableToken() {
                    self.startRefresh(remote, refreshToken: refreshToken)
                } else {
                    self.failRecoverable()
                }
                return
            }
            self.startSilentConnect(remote)
        }
    }

    private func cancelScheduledWork() {
        retryWork?.cancel()
        retryWork = nil
        graceWork?.cancel()
        graceWork = nil
    }

    private func markConnected() {
        retryWork?.cancel()
        retryWork = nil
        failedAutomaticAttempts = 0
        isReconnecting = false
        lastCommandError = nil
        connectionState = .connected
    }

    /// Kalıcı hata: kullanıcının isteği sona erer ve token silinir (yeniden yetkilendirme gerekir).
    private func failTerminal(_ error: MusicProviderError) {
        wantsConnection = false
        isAttemptInFlight = false
        cancelScheduledWork()
        invalidateAuthWork()
        clearToken()
        isReconnecting = false
        resetPlaybackState()
        connectionState = .failed(error)
    }

    /// "Yeniden bağlan" durumu: kullanıcı bağlı kalmak istiyor ve token'ı korunur; sonraki öne gelişte
    /// (token geçerliyse ya da yenilenebiliyorsa) sessizce yeniden denenir, yoksa kullanıcı dokunana dek
    /// Spotify'a gidilmez.
    private func failRecoverable(_ error: MusicProviderError = .connectionLost) {
        isAttemptInFlight = false
        retryWork?.cancel()
        retryWork = nil
        isReconnecting = false
        resetPlaybackState()
        connectionState = .failed(error)
    }

    // MARK: - PKCE (kalıcı bağlantı)

    /// Uygulama içi web sayfasında Spotify izni (PKCE); dönüşteki kod anahtarlara çevrilir ve bağlanılır.
    private func startWebAuthorization() {
        guard let pkce else { return }
        let generation = authGeneration
        let verifier = pkce.makePKCE()
        let state = pkce.makeState()
        let request = SpotifyAuthorizationRequest(
            clientID: pkce.clientID, redirectURL: Self.redirectURL, codeChallenge: verifier.challenge, state: state)
        let scheme = Self.redirectURL.scheme ?? "fokus"
        isWebAuthorizing = true
        connectionState = .connecting
        authTask = Task { [weak self, webAuthenticator = pkce.webAuthenticator] in
            let result = await webAuthenticator.authenticate(url: request.url, callbackScheme: scheme)
            guard let self, self.authGeneration == generation else { return }
            await self.completeWebAuthorization(result, verifier: verifier, state: state, generation: generation)
        }
    }

    private func completeWebAuthorization(
        _ result: SpotifyWebAuthResult, verifier: SpotifyPKCE, state: String, generation: Int
    ) async {
        guard wantsConnection, let pkce else {
            isWebAuthorizing = false
            return
        }
        let code: String
        switch result {
        case .cancelled:
            failTerminal(.authorizationDenied)
            return
        case .failed:
            logger.error("Spotify web yetkilendirmesi açılamadı.")
            failTerminal(.unknown)
            return
        case .callback(let url):
            switch SpotifyCodeCallback.interpret(url, expectedState: state) {
            case .failure(let error):
                logger.error("Spotify izni alınamadı: \(String(describing: error), privacy: .public)")
                failTerminal(error)
                return
            case .code(let value):
                code = value
            }
        }
        let exchange = await pkce.tokenService.exchange(code: code, verifier: verifier.verifier)
        guard authGeneration == generation, wantsConnection, let remote else { return }
        isWebAuthorizing = false
        authTask = nil
        switch exchange {
        case .success(let grant):
            storeToken(SpotifyTokenRecord(grant: grant, issuedAt: now(), previousRefreshToken: nil))
            startSilentConnect(remote)
        case .failure(let failure):
            logger.error("Spotify kodu anahtara çevrilemedi: \(String(describing: failure), privacy: .public)")
            failTerminal(.unknown)
        }
    }

    /// Kullanıcı dokunmadan (öne dönüş) yenileme + bağlanma.
    private func beginAutomaticRefresh(_ remote: any SpotifyRemoteControlling, refreshToken: String) {
        retryWork?.cancel()
        retryWork = nil
        isUserInitiatedAttempt = false
        failedAutomaticAttempts = 0
        isReconnecting = true
        startRefresh(remote, refreshToken: refreshToken)
    }

    /// Yenileme anahtarıyla yeni erişim anahtarı alır (kullanıcıya hiçbir şey gösterilmez), sonra bağlanır.
    private func startRefresh(_ remote: any SpotifyRemoteControlling, refreshToken: String) {
        guard let pkce, !isRefreshing else { return }
        let generation = authGeneration
        isRefreshing = true
        isAttemptInFlight = true
        if connectionState != .connected { connectionState = .connecting }
        authTask = Task { [weak self, tokenService = pkce.tokenService] in
            let result = await tokenService.refresh(refreshToken: refreshToken)
            guard let self, self.authGeneration == generation else { return }
            self.completeRefresh(result, usedRefreshToken: refreshToken)
        }
    }

    private func completeRefresh(_ result: Result<SpotifyTokenGrant, SpotifyTokenFailure>, usedRefreshToken: String) {
        isRefreshing = false
        authTask = nil
        guard wantsConnection, let remote else {
            isAttemptInFlight = false
            return
        }
        switch result {
        case .success(let grant):
            // Spotify yeni yenileme anahtarı döndürdüyse eskisi geçersiz olabilir: arka planda bile kaydedilir.
            storeToken(SpotifyTokenRecord(grant: grant, issuedAt: now(), previousRefreshToken: usedRefreshToken))
            guard !isSuspended else {
                isAttemptInFlight = false
                return
            }
            startSilentConnect(remote)
        case .failure(let failure):
            isAttemptInFlight = false
            logger.error("Spotify anahtarı yenilenemedi: \(String(describing: failure), privacy: .public)")
            switch SpotifyConnectionPolicy.actionAfterTokenFailure(failure, isUserInitiated: isUserInitiatedAttempt) {
            case .reauthorize:
                clearToken()
                remote.setAccessToken(nil)
                startAuthorization(remote)
            case .showReconnect(let discardCredentials, let error):
                if discardCredentials { clearToken() }
                failRecoverable(error)
            }
        }
    }

    // MARK: - SDK olayları

    private func handle(_ event: SpotifyRemoteEvent) {
        switch event {
        case .connected:
            isAttemptInFlight = false
            isSuspended = false
            guard wantsConnection else {
                remote?.disconnect()
                return
            }
            markConnected()
            remote?.subscribeToPlayerState()
        case .connectionFailed(let failure):
            connectionAttemptFailed(failure)
        case .disconnected(let failure):
            // Bilerek kestiğimiz (arka plan/öne dönüş denemesi) kopmalar hata değildir.
            guard !isSuspended, !isAttemptInFlight, wantsConnection, connectionState == .connected else { return }
            logger.info("Spotify bağlantısı koptu (kod \(failure?.code ?? 0, privacy: .public)); yeniden bağlanılıyor.")
            if let remote { beginAutomaticConnect(remote) }
        case .playerState(let snapshot):
            apply(snapshot)
        }
    }

    private func connectionAttemptFailed(_ failure: SpotifyRemoteFailure) {
        isAttemptInFlight = false
        guard wantsConnection, !isSuspended else { return }
        logger.error(
            "Spotify bağlantı denemesi başarısız (kod \(failure.code, privacy: .public)): \(failure.description, privacy: .public)"
        )
        let mapped = SpotifyErrorMapping.connectionError(failure)
        if mapped == .premiumRequired {
            failTerminal(mapped)
            return
        }
        if !isUserInitiatedAttempt { failedAutomaticAttempts += 1 }
        switch SpotifyConnectionPolicy.actionAfterConnectionFailure(
            isUserInitiated: isUserInitiatedAttempt, alreadyReauthorized: hasReauthorized,
            failedAttempts: failedAutomaticAttempts)
        {
        case .retry(let delay):
            scheduleRetry(after: delay)
        case .reauthorize:
            guard let remote else { return }
            hasReauthorized = true
            // Çoğunlukla Spotify çalışmıyordur: App Remote yetkilendirmesi Spotify'ı uyandırır ve yeni bir erişim
            // anahtarı döndürür. Yenileme anahtarı varsa korunur (kullanıcı yeniden izin vermek zorunda kalmaz).
            if token?.canRefresh != true { clearToken() }
            remote.setAccessToken(nil)
            startAppRemoteAuthorization(remote)
        case .fail:
            if token?.canRefresh == true {
                failRecoverable(mapped)
            } else if isUserInitiatedAttempt {
                failTerminal(mapped)
            } else {
                failRecoverable()
            }
        }
    }

    // MARK: - Çalma durumu ve komutlar

    private func apply(_ snapshot: SpotifyPlayerSnapshot) {
        lastCommandError = nil
        if snapshot.imageIdentifier != artworkImageID {
            artworkImageID = snapshot.imageIdentifier
            artworkData = nil
            fetchArtwork(identifier: snapshot.imageIdentifier)
        }
        nowPlaying = MusicTrack(
            title: snapshot.title, artist: snapshot.artist, artworkData: artworkData,
            isPaused: snapshot.isPaused)
    }

    private func fetchArtwork(identifier: String) {
        remote?.fetchArtwork(identifier: identifier, size: Self.artworkSize) { [weak self] data in
            guard let self, self.artworkImageID == identifier, let data else { return }
            self.artworkData = data
            self.nowPlaying?.artworkData = data
        }
    }

    private func send(_ command: SpotifyRemoteCommand) {
        guard let remote, connectionState == .connected else {
            failRecoverable()
            return
        }
        // Sessiz yeniden bağlanma sürerken komut yoksayılır (bağlantı düşmüş gibi hata gösterilmez).
        guard !isReconnecting else { return }
        guard remote.isConnected else {
            failRecoverable()
            return
        }
        remote.send(command) { [weak self] failure in
            guard let failure else { return }
            self?.commandFailed(failure)
        }
    }

    private func commandFailed(_ failure: SpotifyRemoteFailure) {
        logger.error(
            "Spotify komutu başarısız (kod \(failure.code, privacy: .public)): \(failure.description, privacy: .public)"
        )
        let error = SpotifyErrorMapping.commandError(failure)
        if error == .connectionLost {
            failRecoverable()
        } else {
            lastCommandError = error
        }
    }

    private func resetPlaybackState() {
        nowPlaying = nil
        lastCommandError = nil
        artworkImageID = nil
        artworkData = nil
    }
}

/// PKCE ile kalıcı bağlantı için gerekenler (Client ID varsa uygulama hedefi kurar). Client Secret YOKTUR.
@MainActor
public struct SpotifyPKCEAuthorization {
    public var clientID: String
    public var tokenService: any SpotifyTokenServicing
    public var webAuthenticator: any SpotifyWebAuthenticating
    public var makePKCE: () -> SpotifyPKCE
    public var makeState: () -> String

    public init(
        clientID: String,
        tokenService: any SpotifyTokenServicing,
        webAuthenticator: any SpotifyWebAuthenticating,
        makePKCE: @escaping () -> SpotifyPKCE = { SpotifyPKCE.generate() },
        makeState: @escaping () -> String = { SpotifyPKCE.makeState() }
    ) {
        self.clientID = clientID
        self.tokenService = tokenService
        self.webAuthenticator = webAuthenticator
        self.makePKCE = makePKCE
        self.makeState = makeState
    }
}
