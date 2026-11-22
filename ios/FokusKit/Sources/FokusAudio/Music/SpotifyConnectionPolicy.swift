import Foundation

/// Sahne yaşam döngüsünde App Remote'un ne yapacağı kararları (saf; birim testli).
public enum SpotifyConnectionPolicy {
    public enum ActivationAction: Equatable, Sendable {
        case none
        /// Elde geçerli görünen token ile sessizce yeniden bağlan (Spotify'a geçiş yok).
        case silentConnect
    }

    public enum FailureDecision: Equatable, Sendable {
        /// Token reddedilmiş olabilir: Spotify'da yetkilendirmeyi yeniden iste.
        case reauthorize
        case fail
    }

    /// Uygulama öne gelince: kullanıcı bağlı kalmak istiyor, token var ve bağlantı yok/denenmiyorsa
    /// sessiz bağlan. Token yoksa kendiliğinden Spotify'a geçilmez (kullanıcı "Tekrar dene"ye basar).
    public static func activationAction(
        wantsConnection: Bool, hasToken: Bool, isConnected: Bool, isAttemptInFlight: Bool
    ) -> ActivationAction {
        guard wantsConnection, hasToken, !isConnected, !isAttemptInFlight else { return .none }
        return .silentConnect
    }

    /// Bağlantı denemesi başarısız olunca: yalnızca kullanıcının başlattığı denemede ve bir kez
    /// yetkilendirme yenilenir; otomatik (arka plandan dönüş) yeniden bağlanma hata gösterir —
    /// Spotify çalışmıyorsa her öne gelişte kullanıcıyı Spotify'a fırlatmayız.
    public static func decisionAfterConnectionFailure(
        isUserInitiated: Bool, alreadyReauthorized: Bool
    ) -> FailureDecision {
        isUserInitiated && !alreadyReauthorized ? .reauthorize : .fail
    }
}
