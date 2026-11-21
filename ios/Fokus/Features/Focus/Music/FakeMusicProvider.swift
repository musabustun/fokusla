#if DEBUG
import FokusAudio
import Foundation
import Observation

/// UI testleri ve önizlemeler için sahte sağlayıcı: SDK/Spotify gerekmez, durum ayarlanabilir.
@MainActor
@Observable
final class FakeMusicProvider: MusicProvider {
    enum Preset {
        /// Bağlanılabilir, bağlı değil.
        case disconnected
        /// Bağlı, "Odak Müziği — Sakin Piyano" çalıyor.
        case connected
        /// Bağlanma denemesi başarısız.
        case failed
        /// Uygulama yüklü değil ("…'da aç").
        case notInstalled
    }

    static let sampleTrack = MusicTrack(title: "Odak Müziği — Sakin Piyano", artist: "Fokus Sessions")

    let id: MusicProviderID = .spotify
    let displayName = "Spotify"
    let appURL = URL(string: "spotify:")!
    let webURL = URL(string: "https://open.spotify.com")!
    var availability: MusicProviderAvailability
    var connectionState: MusicConnectionState
    var nowPlaying: MusicTrack?
    var lastCommandError: MusicProviderError?

    init(_ preset: Preset) {
        switch preset {
        case .disconnected:
            availability = .available
            connectionState = .disconnected
        case .connected:
            availability = .available
            connectionState = .connected
            nowPlaying = Self.sampleTrack
        case .failed:
            availability = .available
            connectionState = .failed(.authorizationDenied)
        case .notInstalled:
            availability = .appNotInstalled
            connectionState = .disconnected
        }
    }

    func connect() {
        connectionState = .connected
        nowPlaying = Self.sampleTrack
        lastCommandError = nil
    }

    func disconnect() {
        connectionState = .disconnected
        nowPlaying = nil
        lastCommandError = nil
    }

    func togglePlayPause() { nowPlaying?.isPaused.toggle() }
    func skipToNext() {}
    func skipToPrevious() {}
    func handleOpenURL(_ url: URL) -> Bool { false }
    func sceneDidBecomeActive() {}
    func sceneWillResignActive() {}
}
#endif
