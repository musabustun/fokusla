import Foundation

/// SDK'nın `SPTAppRemotePlayerState` değerinin Sendable özeti (SDK nesneleri iş parçacığı sınırını geçmez).
public struct SpotifyPlayerSnapshot: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var isPaused: Bool
    public var imageIdentifier: String

    public init(title: String, artist: String, isPaused: Bool, imageIdentifier: String) {
        self.title = title
        self.artist = artist
        self.isPaused = isPaused
        self.imageIdentifier = imageIdentifier
    }
}

/// SDK delegate/callback olaylarının Sendable karşılığı.
public enum SpotifyRemoteEvent: Equatable, Sendable {
    case connected
    case connectionFailed(SpotifyRemoteFailure)
    case disconnected(SpotifyRemoteFailure?)
    case playerState(SpotifyPlayerSnapshot)
}

public enum SpotifyRemoteCommand: Equatable, Sendable {
    case resume, pause, skipToNext, skipToPrevious
}

/// Spotify iOS SDK'sının (`SPTAppRemote`) kullanılan yüzü. FokusKit SDK'sızdır; gerçek uygulaması
/// uygulama hedefindedir (`SpotifyAppRemoteAdapter`), testler sahte bir uygulama kullanır.
@MainActor
public protocol SpotifyRemoteControlling: AnyObject {
    var isConnected: Bool { get }
    /// SDK olayları ana aktörde bu kapanışa iletilir.
    var onEvent: (@MainActor (SpotifyRemoteEvent) -> Void)? { get set }

    /// Bir sonraki `connect()` için kullanılacak token (`nil` = temizle).
    func setAccessToken(_ token: String?)
    func connect()
    func disconnect()
    /// Spotify'ı açıp yalnızca `app-remote-control` yetkisini ister. `true` = Spotify yüklü, deneme yapılabilir
    /// (yetkilendirmenin başarısı DEĞİL; sonuç `handleOpenURL` ile gelir).
    func authorize(completion: @escaping @MainActor (Bool) -> Void)
    /// Geri dönüş bağlantısındaki parametreler (`access_token`, `error`, `error_description`); SDK ayrıştıramazsa `nil`.
    func authorizationParameters(from url: URL) -> [String: String]?
    /// Çalma durumuna abone olur; değişimler `.playerState` olayı olarak gelir.
    func subscribeToPlayerState()
    func send(_ command: SpotifyRemoteCommand, completion: @escaping @MainActor (SpotifyRemoteFailure?) -> Void)
    /// Kapak görseli baytları (JPEG); alınamazsa `nil`.
    func fetchArtwork(identifier: String, size: CGSize, completion: @escaping @MainActor (Data?) -> Void)
}

/// İptal edilebilir zamanlanmış iş (üstel bekleme ve yetkilendirme toleransı için).
@MainActor
public final class SpotifyScheduledWork {
    private var cancelAction: (@MainActor () -> Void)?

    public init(cancel: @escaping @MainActor () -> Void) {
        cancelAction = cancel
    }

    public func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}

/// Zamanlayıcı soyutlaması: gerçek uygulama `Task.sleep`, testler elle tetiklenen sahte zamanlayıcı kullanır.
@MainActor
public protocol SpotifyScheduling: AnyObject {
    func schedule(after delay: Duration, _ work: @escaping @MainActor () -> Void) -> SpotifyScheduledWork
}

@MainActor
public final class TaskSpotifyScheduler: SpotifyScheduling {
    public init() {}

    public func schedule(after delay: Duration, _ work: @escaping @MainActor () -> Void) -> SpotifyScheduledWork {
        let task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
        return SpotifyScheduledWork { task.cancel() }
    }
}
