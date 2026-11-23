import Foundation

/// Sahne yaşam döngüsünde App Remote'un ne yapacağı kararları (saf; birim testli).
public enum SpotifyConnectionPolicy {
    public enum ActivationAction: Equatable, Sendable {
        case none
        /// Elde geçerli görünen token ile sessizce yeniden bağlan (Spotify'a geçiş yok).
        case silentConnect
        /// Kullanıcı bağlı kalmak istiyor ama token yok/süresi dolmuş: Spotify'a YÖNLENDİRMEDEN "Yeniden bağlan"
        /// durumu göster (kullanıcı dokunursa yetkilendirilir).
        case needsReconnect
    }

    public enum TokenState: Equatable, Sendable {
        case missing, valid, expired
    }

    public enum ConnectionFailureAction: Equatable, Sendable {
        /// Otomatik yeniden bağlanma: bu süre sonra sessizce tekrar dene.
        case retry(after: Duration)
        case reauthorize
        case fail
    }

    /// Otomatik (kullanıcı dokunmadan) yeniden bağlanmada art arda en fazla bu kadar deneme yapılır.
    public static let maxAutomaticAttempts = 5
    private static let backoffBase: Duration = .milliseconds(500)
    private static let backoffCap: Duration = .seconds(8)

    /// `attempt` (1'den başlar) başarısız denemeden sonraki bekleme: 0,5 → 1 → 2 → 4 → 8 sn (üst sınırlı).
    public static func backoffDelay(afterFailedAttempt attempt: Int) -> Duration {
        let exponent = max(0, min(attempt - 1, 10))
        return min(backoffBase * (1 << exponent), backoffCap)
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

extension SpotifyConnectionPolicy {
    /// Uygulama öne gelince (token durumu bilinen sürüm). Bağlıysa ya da deneme sürüyorsa bir şey yapılmaz.
    public static func activationAction(
        wantsConnection: Bool, tokenState: TokenState, isConnected: Bool, isAttemptInFlight: Bool
    ) -> ActivationAction {
        guard wantsConnection, !isConnected, !isAttemptInFlight else { return .none }
        return tokenState == .valid ? .silentConnect : .needsReconnect
    }

    /// Bağlantı denemesi başarısız olunca. Kullanıcının başlattığı denemede bir kez yetkilendirme yenilenir;
    /// otomatik denemelerde (öne dönüş, beklenmedik kopma) `maxAutomaticAttempts`'e kadar üstel bekleme ile
    /// sessizce tekrar denenir, sonra hata gösterilir — kullanıcı Spotify'a fırlatılmaz.
    /// `failedAttempts`: bu başarısızlık dahil art arda başarısız otomatik deneme sayısı.
    public static func actionAfterConnectionFailure(
        isUserInitiated: Bool, alreadyReauthorized: Bool, failedAttempts: Int
    ) -> ConnectionFailureAction {
        if isUserInitiated { return alreadyReauthorized ? .fail : .reauthorize }
        guard failedAttempts < maxAutomaticAttempts else { return .fail }
        return .retry(after: backoffDelay(afterFailedAttempt: failedAttempts))
    }
}
