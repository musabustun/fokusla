import FokusDomain
import Foundation
import WatchConnectivity

/// `WCSession` taşıma katmanı (iPhone uygulaması ve saat uygulaması AYNI dosyayı derler). Yalnızca
/// `FocusLink` sözlüklerini taşır; karar kuralları `FokusDomain` (`FocusLink`), depo erişimi
/// `FocusLinkCoordinator`'dadır.
///
/// Teslimat: karşı taraf erişilebilirse `sendMessage` (anında; saatten gelen mesaj iPhone uygulamasını
/// arka planda uyandırır), gönderim hata verirse ya da erişilemiyorsa `transferUserInfo` (sistem kuyruğu;
/// cihazlar yeniden buluşunca GARANTİLİ teslim). Alıcıda yazma `id` ile idempotenttir; aynı küme iki
/// yoldan da gelse sonuç değişmez.
final class FocusLinkTransport: NSObject, WCSessionDelegate, @unchecked Sendable {
    /// `activate()` ÖNCESİ atanır, sonra değişmez.
    var onRecords: (@MainActor @Sendable (FocusLink.RecordBatch) -> Void)?
    var onPreferences: (@MainActor @Sendable (FocusLink.Preferences) -> Void)?
    var onActivated: (@MainActor @Sendable () -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Eşleşmiş ve karşı uygulama kurulu mu? (iPhone: saat uygulaması; saat: her zaman.)
    var isPeerAvailable: Bool {
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    // MARK: - Gönderme

    /// Kayıt kümesini yollar. Kuyruğa alındıysa ya da yollandıysa `true` (gönderim damgası ilerleyebilir).
    @discardableResult
    func send(_ batch: FocusLink.RecordBatch) -> Bool {
        guard isPeerAvailable, let session, let payload = FocusLink.payload(batch) else { return false }
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return true
        }
        nonisolated(unsafe) let fallback = payload
        session.sendMessage(
            payload, replyHandler: nil,
            errorHandler: { _ in WCSession.default.transferUserInfo(fallback) })
        return true
    }

    /// Görünüm tercihlerini uygulama bağlamıyla yollar (en yenisi kazanır; saat uygulaması kapalıyken de
    /// açılışta okunur).
    func send(_ preferences: FocusLink.Preferences) {
        guard isPeerAvailable, let session, let payload = FocusLink.payload(preferences) else { return }
        try? session.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        guard activationState == .activated else { return }
        let pending = FocusLink.preferences(from: session.receivedApplicationContext)
        Task { @MainActor [onActivated, onPreferences] in
            if let pending { onPreferences?(pending) }
            onActivated?()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let preferences = FocusLink.preferences(from: applicationContext) else { return }
        Task { @MainActor [onPreferences] in onPreferences?(preferences) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        deliver(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        deliver(userInfo)
    }

    private func deliver(_ payload: [String: Any]) {
        guard let batch = FocusLink.records(from: payload) else { return }
        Task { @MainActor [onRecords] in onRecords?(batch) }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Saat değiştirildi: yeni eşleşme için oturumu yeniden etkinleştir.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [onActivated] in onActivated?() }
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [onActivated] in onActivated?() }
    }
}
