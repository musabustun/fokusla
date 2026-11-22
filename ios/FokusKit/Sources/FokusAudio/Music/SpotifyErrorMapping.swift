import Foundation

/// Spotify App Remote hatasının SDK'dan bağımsız özeti (`NSError` → kod + açıklama).
public struct SpotifyRemoteFailure: Error, Equatable, Sendable {
    public var code: Int
    public var description: String

    public init(code: Int, description: String) {
        self.code = code
        self.description = description
    }

    public init(_ error: any Error) {
        let nsError = error as NSError
        self.init(code: nsError.code, description: nsError.localizedDescription)
    }
}

/// App Remote hata kodlarının (`SPTAppRemoteErrorCode`) SDK'sız kopyası.
public enum SpotifyRemoteErrorCode {
    public static let backgroundWakeupFailed = -1000
    public static let connectionAttemptFailed = -1001
    public static let connectionTerminated = -1002
    public static let invalidArguments = -2000
    public static let requestFailed = -2001
}

/// SDK hatası → kullanıcıya gösterilen `MusicProviderError` kararı. Saf; birim testli.
public enum SpotifyErrorMapping {
    /// Premium / kısıtlama gerektiren reddedilen komutları ele veren anahtar sözcükler.
    private static let premiumMarkers = ["premium", "free user", "not allowed", "restricted", "restriction"]

    public static func isPremiumRelated(_ failure: SpotifyRemoteFailure) -> Bool {
        let text = failure.description.lowercased()
        return premiumMarkers.contains { text.contains($0) }
    }

    /// Bağlantı kurma/kopma hataları.
    public static func connectionError(_ failure: SpotifyRemoteFailure) -> MusicProviderError {
        if isPremiumRelated(failure) { return .premiumRequired }
        switch failure.code {
        case SpotifyRemoteErrorCode.backgroundWakeupFailed,
            SpotifyRemoteErrorCode.connectionAttemptFailed,
            SpotifyRemoteErrorCode.connectionTerminated:
            return .connectionLost
        default:
            return .unknown
        }
    }

    /// Oynatma komutu (çal/duraklat/atla) hataları.
    public static func commandError(_ failure: SpotifyRemoteFailure) -> MusicProviderError {
        if isPremiumRelated(failure) { return .premiumRequired }
        if failure.code == SpotifyRemoteErrorCode.connectionTerminated { return .connectionLost }
        return .commandFailed
    }
}
