import FokusAudio
import Foundation
import Observation
import OSLog
import SpotifyiOS
import UIKit

/// Spotify App Remote üzerinden isteğe bağlı müzik denetimi. SDK yalnızca Spotify uygulamasını uzaktan
/// yönetir (ses Spotify'dan çalar). Token YALNIZCA bellekte tutulur; kalıcı saklama ve sunucu yoktur.
@MainActor
@Observable
final class SpotifyMusicProvider: MusicProvider {
    /// Spotify Developer Dashboard'daki redirect URI ile BİREBİR aynı olmalı (xcconfig'e konmaz: `//`
    /// xcconfig'te yorum başlatır).
    static let redirectURL = URL(string: "fokus://spotify-callback")!

    private static let artworkSize = CGSize(width: 600, height: 600)
    /// Yetkilendirmeden dönüşte `onOpenURL` gecikirse beklenen süre; dolunca iptal sayılır.
    private static let authorizationGrace: Duration = .seconds(2)

    let id: MusicProviderID = .spotify
    let displayName = "Spotify"
    let appURL = URL(string: "spotify:")!
    let webURL = URL(string: "https://open.spotify.com")!
    private(set) var availability: MusicProviderAvailability
    private(set) var connectionState: MusicConnectionState = .disconnected
    private(set) var nowPlaying: MusicTrack?
    private(set) var lastCommandError: MusicProviderError?

    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.musabustun.fokus", category: "focus-spotify")
    @ObservationIgnored private let canOpenURL: @MainActor (URL) -> Bool
    @ObservationIgnored private let appRemote: SPTAppRemote?
    @ObservationIgnored private var delegateProxy: SpotifyRemoteDelegateProxy?

    /// Bellekte tutulan erişim token'ı (kalıcı değil).
    @ObservationIgnored private var accessToken: String?
    /// Kullanıcı bağlı kalmak istiyor (bağlan'a bastı, bağlantıyı kesmedi).
    @ObservationIgnored private var wantsConnection = false
    @ObservationIgnored private var awaitingAuthorization = false
    @ObservationIgnored private var isAttemptInFlight = false
    @ObservationIgnored private var isUserInitiatedAttempt = false
    @ObservationIgnored private var hasReauthorized = false
    /// Arka plana geçerken SDK bağlantısını bilerek kestik; `didDisconnect` hata sayılmaz.
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var graceTask: Task<Void, Never>?
    @ObservationIgnored private var artworkImageID: String?
    @ObservationIgnored private var artworkData: Data?

    /// `clientID` boşsa entegrasyon gizlenir ve hiçbir SDK nesnesi kurulmaz.
    init(
        clientID: String,
        canOpenURL: @escaping @MainActor (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }
    ) {
        self.canOpenURL = canOpenURL
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            appRemote = nil
            availability = .notConfigured
            return
        }
        let configuration = SPTConfiguration(clientID: trimmed, redirectURL: Self.redirectURL)
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .error)
        availability = canOpenURL(URL(string: "spotify:")!) ? .available : .appNotInstalled
        let proxy = SpotifyRemoteDelegateProxy { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        delegateProxy = proxy
        appRemote?.delegate = proxy
    }

    /// `Info.plist`'teki `SpotifyClientID` (xcconfig `SPOTIFY_CLIENT_ID`); boşsa entegrasyon gizlenir.
    static func make(bundle: Bundle = .main) -> SpotifyMusicProvider {
        SpotifyMusicProvider(clientID: bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "")
    }

    // MARK: - MusicProvider

    func connect() {
        refreshAvailability()
        guard let appRemote, availability == .available else {
            connectionState = .failed(availability == .notConfigured ? .notConfigured : .appNotInstalled)
            return
        }
        guard connectionState != .connected, connectionState != .connecting else { return }
        wantsConnection = true
        isUserInitiatedAttempt = true
        hasReauthorized = false
        lastCommandError = nil
        connectionState = .connecting
        if accessToken != nil {
            startSilentConnect(appRemote)
        } else {
            startAuthorization(appRemote)
        }
    }

    /// Kullanıcının isteğiyle keser ve token'ı atar; Spotify çalmaya devam eder (durdurma komutu gönderilmez).
    func disconnect() {
        wantsConnection = false
        awaitingAuthorization = false
        isAttemptInFlight = false
        isSuspended = false
        graceTask?.cancel()
        accessToken = nil
        appRemote?.connectionParameters.accessToken = nil
        appRemote?.disconnect()
        resetPlaybackState()
        connectionState = .disconnected
    }

    func togglePlayPause() {
        let isPaused = nowPlaying?.isPaused ?? false
        send { player, callback in
            if isPaused { player.resume(callback) } else { player.pause(callback) }
        }
    }

    func skipToNext() { send { $0.skip(toNext: $1) } }

    func skipToPrevious() { send { $0.skip(toPrevious: $1) } }

    func handleOpenURL(_ url: URL) -> Bool {
        guard SpotifyAuthCallback.matches(url, redirect: Self.redirectURL) else { return false }
        guard let appRemote else { return true }
        awaitingAuthorization = false
        graceTask?.cancel()
        guard wantsConnection else { return true }

        let outcome: SpotifyAuthCallback
        if let sdkParameters = appRemote.authorizationParameters(from: url) {
            outcome = SpotifyAuthCallback.interpret([
                "access_token": sdkParameters[SPTAppRemoteAccessTokenKey] ?? "",
                "error_description": sdkParameters[SPTAppRemoteErrorDescriptionKey] ?? "",
                "error": sdkParameters[SPTAppRemoteErrorKey] ?? "",
            ])
        } else {
            outcome = SpotifyAuthCallback.interpret(SpotifyAuthCallback.parameters(from: url))
        }
        switch outcome {
        case .token(let token):
            accessToken = token
            startSilentConnect(appRemote)
        case .failure(let error):
            logger.error("Yetkilendirme tamamlanmadı: \(String(describing: error), privacy: .public)")
            fail(error)
        }
        return true
    }

    func sceneDidBecomeActive() {
        refreshAvailability()
        guard availability == .available, let appRemote else { return }
        if awaitingAuthorization {
            scheduleAuthorizationGrace()
            return
        }
        isSuspended = false
        let action = SpotifyConnectionPolicy.activationAction(
            wantsConnection: wantsConnection, hasToken: accessToken != nil,
            isConnected: appRemote.isConnected, isAttemptInFlight: isAttemptInFlight)
        guard action == .silentConnect else { return }
        isUserInitiatedAttempt = false
        startSilentConnect(appRemote)
    }

    /// SDK önerisi: ön planda değilken bağlantıyı kes. Kullanıcı bağlı kalmak istiyorsa durum ve çalan
    /// parça korunur (titreme olmasın); öne dönünce sessizce yeniden bağlanılır.
    func sceneWillResignActive() {
        graceTask?.cancel()
        guard !awaitingAuthorization, let appRemote, appRemote.isConnected || isAttemptInFlight else { return }
        isSuspended = true
        isAttemptInFlight = false
        appRemote.disconnect()
    }

    // MARK: - Bağlantı

    private func refreshAvailability() {
        guard appRemote != nil else { return }
        let updated: MusicProviderAvailability = canOpenURL(appURL) ? .available : .appNotInstalled
        guard updated != availability else { return }
        availability = updated
        if updated != .available, connectionState != .disconnected {
            appRemote?.disconnect()
            wantsConnection = false
            resetPlaybackState()
            connectionState = .disconnected
        }
    }

    /// Spotify'a gidip izin ister; Spotify çalışmıyorsa uyandırır (son çalan parçayı sürdürebilir).
    private func startAuthorization(_ appRemote: SPTAppRemote) {
        awaitingAuthorization = true
        appRemote.authorizeAndPlayURI("") { @Sendable [weak self] success in
            guard !success else { return }
            Task { @MainActor in
                guard let self else { return }
                self.awaitingAuthorization = false
                self.refreshAvailability()
                self.fail(.appNotInstalled)
            }
        }
    }

    private func startSilentConnect(_ appRemote: SPTAppRemote) {
        appRemote.connectionParameters.accessToken = accessToken
        isAttemptInFlight = true
        if connectionState != .connected { connectionState = .connecting }
        appRemote.connect()
    }

    private func scheduleAuthorizationGrace() {
        graceTask?.cancel()
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.authorizationGrace)
            guard !Task.isCancelled, let self, self.awaitingAuthorization else { return }
            self.awaitingAuthorization = false
            self.logger.info("Yetkilendirmeden geri dönüş bağlantısı gelmedi; iptal sayıldı.")
            self.fail(.authorizationDenied)
        }
    }

    private func fail(_ error: MusicProviderError) {
        wantsConnection = false
        isAttemptInFlight = false
        resetPlaybackState()
        connectionState = .failed(error)
    }

    // MARK: - SDK olayları

    private func handle(_ event: SpotifyRemoteEvent) {
        switch event {
        case .connected:
            isAttemptInFlight = false
            isSuspended = false
            guard wantsConnection else {
                appRemote?.disconnect()
                return
            }
            connectionState = .connected
            subscribeToPlayerState()
        case .connectionFailed(let failure):
            connectionAttemptFailed(failure)
        case .disconnected(let failure):
            guard !isSuspended, wantsConnection else { return }
            logger.info("Spotify bağlantısı koptu (kod \(failure?.code ?? 0, privacy: .public)).")
            fail(.connectionLost)
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
        let decision = SpotifyConnectionPolicy.decisionAfterConnectionFailure(
            isUserInitiated: isUserInitiatedAttempt, alreadyReauthorized: hasReauthorized)
        if decision == .reauthorize, let appRemote {
            hasReauthorized = true
            accessToken = nil
            appRemote.connectionParameters.accessToken = nil
            startAuthorization(appRemote)
        } else {
            fail(SpotifyErrorMapping.connectionError(failure))
        }
    }

    private func subscribeToPlayerState() {
        guard let player = appRemote?.playerAPI else { return }
        player.delegate = delegateProxy
        player.subscribe(
            toPlayerState: SpotifyRemoteCallbacks.playerState { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let snapshot): self?.apply(snapshot)
                    case .failure(let failure):
                        self?.logger.error(
                            "Çalma durumu aboneliği başarısız: \(failure.description, privacy: .public)")
                    }
                }
            })
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
        appRemote?.imageAPI?.fetchImage(
            forItem: SpotifyImageReference(identifier: identifier), with: Self.artworkSize,
            callback: SpotifyRemoteCallbacks.artwork { [weak self] data in
                Task { @MainActor in
                    guard let self, self.artworkImageID == identifier, let data else { return }
                    self.artworkData = data
                    self.nowPlaying?.artworkData = data
                }
            })
    }

    private func send(
        _ command: (any SPTAppRemotePlayerAPI, @escaping SPTAppRemoteCallback) -> Void
    ) {
        guard let player = appRemote?.playerAPI, connectionState == .connected else {
            fail(.connectionLost)
            return
        }
        command(
            player,
            SpotifyRemoteCallbacks.command { [weak self] failure in
                guard let failure else { return }
                Task { @MainActor in self?.commandFailed(failure) }
            })
    }

    private func commandFailed(_ failure: SpotifyRemoteFailure) {
        logger.error(
            "Spotify komutu başarısız (kod \(failure.code, privacy: .public)): \(failure.description, privacy: .public)"
        )
        let error = SpotifyErrorMapping.commandError(failure)
        if error == .connectionLost {
            fail(error)
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
