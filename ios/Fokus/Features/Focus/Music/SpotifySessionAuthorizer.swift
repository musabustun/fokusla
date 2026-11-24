import FokusAudio
import Foundation
import OSLog
import SpotifyiOS
import UIKit

/// `SpotifyAppAuthorizing`'in gerçek uygulaması: Spotify iOS SDK'sının `SPTSessionManager`'ı. İzin Spotify
/// UYGULAMASINDA istenir (şifre sorulmaz; Spotify'daki oturum kullanılır), dönüşteki kodu SDK PKCE ile
/// (`accounts.spotify.com`, Client Secret YOK) erişim + yenileme anahtarına çevirir. `playURI = ""` Spotify'ı
/// uyandırıp kaldığı parçayı çaldırır; böylece App Remote bağlantısı hemen kurulur. Yetki yalnızca
/// `app-remote-control`.
@MainActor
final class SpotifySessionAuthorizer: SpotifyAppAuthorizing {
    private let manager: SPTSessionManager
    private let delegateProxy: SpotifySessionDelegateProxy
    private var continuation: CheckedContinuation<SpotifyAppAuthResult, Never>?
    /// Dönüş bağlantısı geldi, SDK kodu anahtara çeviriyor (iptal edilmez).
    private var isExchanging = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.musabustun.fokus", category: "focus-spotify")

    init(clientID: String) {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: SpotifyMusicProvider.redirectURL)
        configuration.playURI = ""
        let sink = Sink()
        delegateProxy = SpotifySessionDelegateProxy { result in sink.deliver(result) }
        manager = SPTSessionManager(configuration: configuration, delegate: delegateProxy)
        sink.owner = self
    }

    func authorize() async -> SpotifyAppAuthResult {
        finish(.cancelled)
        isExchanging = false
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            // Yalnızca Spotify uygulaması (yüklü olduğu bilinir); web sayfasına düşülmez.
            manager.initiateSession(with: .appRemoteControl, options: .clientOnly, campaign: nil)
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        guard continuation != nil else { return false }
        let handled = manager.application(UIApplication.shared, open: url, options: [:])
        if handled { isExchanging = true }
        return handled
    }

    func cancelPendingAuthorization() {
        guard !isExchanging else { return }
        finish(.cancelled)
    }

    fileprivate func complete(_ result: SpotifyAppAuthResult) {
        if case .failed = result { logger.error("SPTSessionManager izni tamamlanamadı.") }
        finish(result)
    }

    private func finish(_ result: SpotifyAppAuthResult) {
        let pending = continuation
        continuation = nil
        isExchanging = false
        pending?.resume(returning: result)
    }

    /// Delegate (herhangi bir iş parçacığı) → ana aktör köprüsü.
    private final class Sink: @unchecked Sendable {
        nonisolated(unsafe) weak var owner: SpotifySessionAuthorizer?

        func deliver(_ result: SpotifyAppAuthResult) {
            Task { @MainActor [weak self] in self?.owner?.complete(result) }
        }
    }
}

/// `SPTSessionManagerDelegate` (ObjC, `NSObject` zorunlu): SDK oturumunu Sendable sonuca çevirir.
final class SpotifySessionDelegateProxy: NSObject, SPTSessionManagerDelegate, Sendable {
    private let emit: @Sendable (SpotifyAppAuthResult) -> Void

    init(emit: @escaping @Sendable (SpotifyAppAuthResult) -> Void) {
        self.emit = emit
    }

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        let grant = SpotifyTokenGrant(
            accessToken: session.accessToken,
            expiresIn: max(0, session.expirationDate.timeIntervalSinceNow),
            refreshToken: session.refreshToken.isEmpty ? nil : session.refreshToken)
        emit(.granted(grant))
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: any Error) {
        let text = (error as NSError).localizedDescription.lowercased()
        let wasDenied = text.contains("denied") || text.contains("cancel")
        emit(wasDenied ? .cancelled : .failed)
    }
}
