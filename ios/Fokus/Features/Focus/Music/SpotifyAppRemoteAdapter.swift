import FokusAudio
import Foundation
import OSLog
import SpotifyiOS
import UIKit

/// `SpotifyRemoteControlling`'in gerçek uygulaması: Spotify iOS SDK'sı (`SPTAppRemote`). SDK yalnızca Spotify
/// uygulamasını uzaktan yönetir (ses Spotify'dan çalar). Yetki yalnızca `app-remote-control`; kullanıcı
/// adı/fotoğrafı/e-postası istenmez ve Web API kullanılmaz. Token saklama ve yenileme `SpotifyMusicProvider`'ın
/// işidir. Buradaki `authorize` yalnızca PKCE olmadan (ya da Spotify'ı uyandırmak için) kullanılır.
@MainActor
final class SpotifyAppRemoteAdapter: SpotifyRemoteControlling {
    var onEvent: (@MainActor (SpotifyRemoteEvent) -> Void)?

    private let appRemote: SPTAppRemote
    private let delegateProxy: SpotifyRemoteDelegateProxy
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.musabustun.fokus", category: "focus-spotify")

    init(clientID: String) {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: SpotifyMusicProvider.redirectURL)
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .error)
        // Delegate ObjC/iş parçacığı belirsiz: yalnızca Sendable olay üretir; ana aktöre taşınır.
        let sink = EventSink()
        delegateProxy = SpotifyRemoteDelegateProxy { event in sink.deliver(event) }
        appRemote.delegate = delegateProxy
        sink.adapter = self
    }

    var isConnected: Bool { appRemote.isConnected }

    func setAccessToken(_ token: String?) { appRemote.connectionParameters.accessToken = token }

    func connect() { appRemote.connect() }

    func disconnect() { appRemote.disconnect() }

    func authorize(completion: @escaping @MainActor (Bool) -> Void) {
        // Boş URI = kullanıcının son parçası; ek kapsam yok (yalnızca varsayılan `app-remote-control`).
        appRemote.authorizeAndPlayURI("") { @Sendable success in
            Task { @MainActor in completion(success) }
        }
    }

    func authorizationParameters(from url: URL) -> [String: String]? {
        guard let parameters = appRemote.authorizationParameters(from: url) else { return nil }
        return [
            "access_token": parameters[SPTAppRemoteAccessTokenKey] ?? "",
            "error_description": parameters[SPTAppRemoteErrorDescriptionKey] ?? "",
            "error": parameters[SPTAppRemoteErrorKey] ?? "",
        ]
    }

    func subscribeToPlayerState() {
        guard let player = appRemote.playerAPI else { return }
        player.delegate = delegateProxy
        player.subscribe(
            toPlayerState: SpotifyRemoteCallbacks.playerState { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let snapshot): self?.onEvent?(.playerState(snapshot))
                    case .failure(let failure):
                        self?.logger.error(
                            "Çalma durumu aboneliği başarısız: \(failure.description, privacy: .public)")
                    }
                }
            })
    }

    func send(_ command: SpotifyRemoteCommand, completion: @escaping @MainActor (SpotifyRemoteFailure?) -> Void) {
        guard let player = appRemote.playerAPI else {
            completion(
                SpotifyRemoteFailure(code: SpotifyRemoteErrorCode.connectionTerminated, description: ""))
            return
        }
        let callback = SpotifyRemoteCallbacks.command { failure in
            Task { @MainActor in completion(failure) }
        }
        switch command {
        case .resume: player.resume(callback)
        case .pause: player.pause(callback)
        case .skipToNext: player.skip(toNext: callback)
        case .skipToPrevious: player.skip(toPrevious: callback)
        }
    }

    func fetchArtwork(identifier: String, size: CGSize, completion: @escaping @MainActor (Data?) -> Void) {
        appRemote.imageAPI?.fetchImage(
            forItem: SpotifyImageReference(identifier: identifier), with: size,
            callback: SpotifyRemoteCallbacks.artwork { data in
                Task { @MainActor in completion(data) }
            })
    }

    /// Delegate (herhangi bir iş parçacığı) → ana aktördeki adaptör köprüsü.
    private final class EventSink: @unchecked Sendable {
        nonisolated(unsafe) weak var adapter: SpotifyAppRemoteAdapter?

        func deliver(_ event: SpotifyRemoteEvent) {
            Task { @MainActor [weak self] in self?.adapter?.onEvent?(event) }
        }
    }
}

extension SpotifyMusicProvider {
    /// `Info.plist`'teki `SpotifyClientID` (xcconfig `SPOTIFY_CLIENT_ID`); boşsa entegrasyon gizlenir ve SDK
    /// nesnesi kurulmaz. Anahtarlar Keychain'de saklanır; erişim anahtarı yalnızca `accounts.spotify.com` ile
    /// (PKCE, Client Secret YOK) sessizce yenilenir.
    @MainActor
    static func make(bundle: Bundle = .main) -> SpotifyMusicProvider {
        let clientID = (bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            return SpotifyMusicProvider(
                remote: nil, tokenStore: KeychainSpotifyTokenStore(),
                canOpenURL: { UIApplication.shared.canOpenURL($0) })
        }
        return SpotifyMusicProvider(
            remote: SpotifyAppRemoteAdapter(clientID: clientID),
            tokenStore: KeychainSpotifyTokenStore(),
            canOpenURL: { UIApplication.shared.canOpenURL($0) },
            pkce: SpotifyPKCEAuthorization(
                clientID: clientID,
                tokenService: URLSessionSpotifyTokenService(clientID: clientID, redirectURL: redirectURL),
                webAuthenticator: SpotifyWebAuthSession()))
    }
}

// MARK: - SDK köprüsü (ObjC delegate + callback'ler)

/// SDK'nın ObjC delegate'lerini (`NSObject` zorunlu, çağrıldığı iş parçacığı garanti değil) Swift 6
/// aktör modelinden ayırır: yalnızca Sendable olay üretir.
final class SpotifyRemoteDelegateProxy: NSObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate,
    Sendable
{
    private let emit: @Sendable (SpotifyRemoteEvent) -> Void

    init(emit: @escaping @Sendable (SpotifyRemoteEvent) -> Void) {
        self.emit = emit
    }

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        emit(.connected)
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: (any Error)?) {
        emit(.connectionFailed(Self.failure(error)))
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: (any Error)?) {
        emit(.disconnected(error.map(SpotifyRemoteFailure.init)))
    }

    func playerStateDidChange(_ playerState: any SPTAppRemotePlayerState) {
        if let snapshot = SpotifyRemoteCallbacks.snapshot(playerState) { emit(.playerState(snapshot)) }
    }

    private static func failure(_ error: (any Error)?) -> SpotifyRemoteFailure {
        error.map(SpotifyRemoteFailure.init)
            ?? SpotifyRemoteFailure(code: SpotifyRemoteErrorCode.connectionAttemptFailed, description: "")
    }
}

/// Kapak görselini istemek için gereken tek alan (`SPTAppRemoteImageRepresentable`).
final class SpotifyImageReference: NSObject, SPTAppRemoteImageRepresentable, Sendable {
    let imageIdentifier: String

    init(identifier: String) {
        imageIdentifier = identifier
    }
}

/// SDK callback'leri (`(Any?, Error?) -> Void`) hangi iş parçacığından gelirse gelsin güvenli kalsın diye
/// SDK değerlerini callback içinde Sendable özetlere çevirir.
enum SpotifyRemoteCallbacks {
    /// `playerState` SDK'dan gelen `Any?` sonuç ya da delegate parametresidir. Yalnızca çalma için gerekenler okunur.
    static func snapshot(_ playerState: Any?) -> SpotifyPlayerSnapshot? {
        guard let state = playerState as? any SPTAppRemotePlayerState else { return nil }
        return SpotifyPlayerSnapshot(
            title: state.track.name, artist: state.track.artist.name, isPaused: state.isPaused,
            imageIdentifier: state.track.imageIdentifier)
    }

    /// Komut sonucu: `nil` = başarı.
    static func command(
        _ completion: @escaping @Sendable (SpotifyRemoteFailure?) -> Void
    ) -> SPTAppRemoteCallback {
        { _, error in completion(error.map(SpotifyRemoteFailure.init)) }
    }

    /// Çalma durumu (abonelik / ilk okuma).
    static func playerState(
        _ completion: @escaping @Sendable (Result<SpotifyPlayerSnapshot, SpotifyRemoteFailure>) -> Void
    ) -> SPTAppRemoteCallback {
        { result, error in
            if let error {
                completion(.failure(SpotifyRemoteFailure(error)))
            } else if let snapshot = snapshot(result) {
                completion(.success(snapshot))
            } else {
                completion(
                    .failure(SpotifyRemoteFailure(code: SpotifyRemoteErrorCode.requestFailed, description: "")))
            }
        }
    }

    /// Kapak görseli → JPEG baytları (`UIImage` ana aktörü geçmesin diye burada kodlanır).
    static func artwork(_ completion: @escaping @Sendable (Data?) -> Void) -> SPTAppRemoteCallback {
        { result, _ in completion((result as? UIImage)?.jpegData(compressionQuality: 0.9)) }
    }
}
