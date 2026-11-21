import FokusAudio
import Foundation
import SpotifyiOS
import UIKit

/// SDK'nın `SPTAppRemotePlayerState` değerinin Sendable özeti (SDK nesneleri iş parçacığı sınırını geçmez).
struct SpotifyPlayerSnapshot: Equatable, Sendable {
    var title: String
    var artist: String
    var isPaused: Bool
    var imageIdentifier: String

    /// `playerState` SDK'dan gelen `Any?` sonuç ya da delegate parametresidir.
    init?(_ playerState: Any?) {
        guard let state = playerState as? any SPTAppRemotePlayerState else { return nil }
        title = state.track.name
        artist = state.track.artist.name
        isPaused = state.isPaused
        imageIdentifier = state.track.imageIdentifier
    }
}

/// Delegate/callback olaylarının Sendable karşılığı; ana aktöre taşınıp orada işlenir.
enum SpotifyRemoteEvent: Sendable {
    case connected
    case connectionFailed(SpotifyRemoteFailure)
    case disconnected(SpotifyRemoteFailure?)
    case playerState(SpotifyPlayerSnapshot)
}

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
        if let snapshot = SpotifyPlayerSnapshot(playerState) { emit(.playerState(snapshot)) }
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
            } else if let snapshot = SpotifyPlayerSnapshot(result) {
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
