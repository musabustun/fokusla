import FokusAudio
import Foundation
import Observation

/// GEÇİCİ İSKELET — gerçek Spotify App Remote uygulaması Spotify işiyle bu dosyanın yerine geçer.
@MainActor
@Observable
final class SpotifyMusicProvider: MusicProvider {
    /// Spotify Developer Dashboard'daki redirect URI ile BİREBİR aynı olmalı (xcconfig'e konmaz: `//`
    /// xcconfig'te yorum başlatır).
    static let redirectURL = URL(string: "fokus://spotify-callback")!

    let id: MusicProviderID = .spotify
    let displayName = "Spotify"
    private(set) var availability: MusicProviderAvailability = .notConfigured
    private(set) var connectionState: MusicConnectionState = .disconnected
    private(set) var nowPlaying: MusicTrack?
    let appURL = URL(string: "spotify:")!
    let webURL = URL(string: "https://open.spotify.com")!

    /// `Info.plist`'teki `SpotifyClientID` (xcconfig `SPOTIFY_CLIENT_ID`); boşsa entegrasyon gizlenir.
    init(clientID: String) {}

    static func make(bundle: Bundle = .main) -> SpotifyMusicProvider {
        SpotifyMusicProvider(clientID: bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "")
    }

    func connect() {}
    func disconnect() {}
    func togglePlayPause() {}
    func skipToNext() {}
    func skipToPrevious() {}
    func handleOpenURL(_ url: URL) -> Bool { false }
    func sceneDidBecomeActive() {}
    func sceneWillResignActive() {}
}
