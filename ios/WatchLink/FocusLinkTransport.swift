import FokusDomain
import Foundation
import WatchConnectivity

/// `WCSession` taşıma katmanı (iPhone uygulaması ve saat uygulaması AYNI dosyayı derler). Yalnızca
/// `FocusLink` sözlüklerini taşır; karar kuralları `FokusDomain/FocusLink`'te, depo erişimi
/// `FocusLinkCoordinator`'dadır. Veri CloudKit'ten akar; bu katman yalnızca "şu an durum bu" bildirimi ve
/// (oturum karşı cihazdayken) uzaktan komut içindir. Telefon yakında değilse hiçbir şey yapmaz.
final class FocusLinkTransport: NSObject, WCSessionDelegate, @unchecked Sendable {
    /// `activate()` ÖNCESİ atanır, sonra değişmez.
    var onBroadcast: (@MainActor @Sendable (FocusLink.Broadcast) -> Void)?
    var onCommand: (@MainActor @Sendable (FocusLink.Command) async -> Bool)?
    var onActivated: (@MainActor @Sendable () -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Eşleşmiş ve karşı uygulama kurulu mu? (iPhone: saat uygulaması; saat: her zaman.)
    private var isPeerAvailable: Bool {
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    // MARK: - Gönderme

    /// Bildirimi yollar: bağlam (en yeni kazanır; karşı uygulama açılınca da ulaşır) + yakındaysa anlık mesaj.
    func send(_ broadcast: FocusLink.Broadcast) {
        guard isPeerAvailable, let session, let payload = FocusLink.payload(broadcast) else { return }
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Komutu karşı cihaza yollar; yanıt gelirse onun sonucu, ulaşılamazsa `false`.
    func send(_ command: FocusLink.Command) async -> Bool {
        guard isPeerAvailable, let session, session.isReachable, let payload = FocusLink.payload(command)
        else { return false }
        return await withCheckedContinuation { continuation in
            session.sendMessage(
                payload,
                replyHandler: { reply in continuation.resume(returning: reply["ok"] as? Bool ?? false) },
                errorHandler: { _ in continuation.resume(returning: false) })
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        guard activationState == .activated else { return }
        let pending = FocusLink.broadcast(from: session.receivedApplicationContext)
        Task { @MainActor [onBroadcast, onActivated] in
            if let pending { onBroadcast?(pending) }
            onActivated?()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = FocusLink.command(from: message) else {
            deliver(message)
            replyHandler(["ok": true])
            return
        }
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor [onCommand] in
            let handled = await onCommand?(command) ?? false
            reply(["ok": handled])
        }
    }

    private func deliver(_ payload: [String: Any]) {
        guard let broadcast = FocusLink.broadcast(from: payload) else { return }
        Task { @MainActor [onBroadcast] in onBroadcast?(broadcast) }
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
}
