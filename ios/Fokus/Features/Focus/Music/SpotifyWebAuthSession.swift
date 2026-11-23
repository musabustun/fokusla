import AuthenticationServices
import FokusAudio
import Foundation
import UIKit

/// `SpotifyWebAuthenticating`'in gerçek uygulaması: Spotify izin sayfası (`accounts.spotify.com/authorize`,
/// PKCE) sistemin güvenli web oturumunda açılır; Fokus sayfanın içeriğini ve şifreyi göremez. Dönüş
/// (`fokus://spotify-callback?code=…`) oturum tarafından yakalanır. Bu sayfa yalnızca ilk bağlanışta ya da
/// kullanıcı Spotify'da erişimi kaldırdıktan sonra görünür; sonrasında anahtar sessizce yenilenir.
@MainActor
final class SpotifyWebAuthSession: NSObject, SpotifyWebAuthenticating {
    private var session: ASWebAuthenticationSession?
    private let anchorProvider = AnchorProvider()

    func authenticate(url: URL, callbackScheme: String) async -> SpotifyWebAuthResult {
        await withCheckedContinuation { continuation in
            let resume = ResumeOnce(continuation)
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) {
                [weak self] callbackURL, error in
                if let callbackURL {
                    resume(.callback(callbackURL))
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    resume(.cancelled)
                } else {
                    resume(.failed)
                }
                Task { @MainActor in self?.session = nil }
            }
            session.presentationContextProvider = anchorProvider
            // Safari'deki Spotify oturumu kullanılabilsin (çoğu kullanıcı yeniden şifre yazmaz).
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                self.session = nil
                resume(.failed)
            }
        }
    }

    /// Devam ettirmenin tek kez yapılmasını garanti eder (başlatma hatası + tamamlama yarışına karşı).
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<SpotifyWebAuthResult, Never>?

        init(_ continuation: CheckedContinuation<SpotifyWebAuthResult, Never>) {
            self.continuation = continuation
        }

        func callAsFunction(_ result: SpotifyWebAuthResult) {
            let pending = lock.withLock { () -> CheckedContinuation<SpotifyWebAuthResult, Never>? in
                defer { continuation = nil }
                return continuation
            }
            pending?.resume(returning: result)
        }
    }

    /// İzin sayfasının sunulacağı pencere (etkin sahnenin anahtar penceresi).
    private final class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                let ordered =
                    scenes.filter { $0.activationState == .foregroundActive }
                    + scenes.filter { $0.activationState != .foregroundActive }
                if let window = ordered.flatMap(\.windows).first(where: \.isKeyWindow)
                    ?? ordered.first?.windows.first
                {
                    return window
                }
                guard let scene = ordered.first else { return ASPresentationAnchor() }
                return ASPresentationAnchor(windowScene: scene)
            }
        }
    }
}
