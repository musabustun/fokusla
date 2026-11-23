import OSLog
import WatchKit

private let logger = Logger(subsystem: "com.musabustun.fokus.watch", category: "runtime")

/// Odak sürerken uygulamayı kadranda tutar: bilek indirilince ya da ekran avuçla kapatılınca saat
/// kadrana dönmez, Always On'da kısık kadranı gösterir (Spotify "Şimdi Çalıyor" gibi).
///
/// `WKExtendedRuntimeSession`, "mindfulness" türü (Info.plist `WKBackgroundModes`): ön planda tutan
/// oturum, en çok 1 saat. Süre dolunca sistem kapatır; kullanıcı bileğini kaldırıp uygulama yeniden
/// etkin olunca (odak hâlâ sürüyorsa) yeni oturum açılır. `HKWorkoutSession` bilerek KULLANILMAZ
/// (antrenman değil; inceleme reddi riski). Gerekçe: `appstore/metadata/tr/review_notes.txt`.
@MainActor
final class WatchRuntimeSession: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?

    /// Odak açık + uygulama etkin → oturum açık olsun; odak bitti → kapansın.
    func update(isFocusRunning: Bool, isActive: Bool) {
        if !isFocusRunning {
            session?.invalidate()
            session = nil
            return
        }
        guard isActive, session == nil || session?.state == .invalid else { return }
        let next = WKExtendedRuntimeSession()
        next.delegate = self
        next.start()
        session = next
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?
    ) {
        if let error {
            logger.notice("Kadranda kalma oturumu kapandı: \(error.localizedDescription, privacy: .public)")
        }
    }
}
