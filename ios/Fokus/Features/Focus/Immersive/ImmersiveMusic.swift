import FokusAudio
import FokusDesign
import SwiftUI

/// Tam ekranın müzik girdisi: kayıttaki sağlayıcının (Spotify, yoksa ilk) bağlı + çalan durumu.
/// Yalnızca okur; sağlayıcılar `@Observable` olduğundan bu değer görünüm gövdesinde kurulunca durum izlenir.
@MainActor
struct ImmersiveMusic {
    let provider: (any MusicProvider)?

    static let none = ImmersiveMusic(provider: nil)

    init(provider: (any MusicProvider)?) { self.provider = provider }

    init(registry: MusicProviderRegistry?) {
        self.provider = registry?.provider(.spotify) ?? registry?.providers.first
    }

    /// Müzik sayfası/çipi için yeterli: bağlı ve çalan parça var.
    var isConnected: Bool { provider?.connectionState == .connected }

    var info: NowPlayingInfo? {
        guard isConnected, let track = provider?.nowPlaying else { return nil }
        return NowPlayingInfo(
            title: track.title, artist: track.artist, artworkData: track.artworkData, isPaused: track.isPaused)
    }

    /// Sayfa listesinde müzik görünsün mü?
    var isAvailable: Bool { info != nil }

    var errorMessage: String? { provider?.lastCommandError?.userMessage }

    func previous() { provider?.skipToPrevious() }
    func playPause() { provider?.togglePlayPause() }
    func next() { provider?.skipToNext() }
}

/// "Şimdi çalıyor" kartı (yalnızca müzik bağlıyken sayfa listesinde).
struct ImmersiveMusicPage: View {
    let context: ImmersivePageContext

    var body: some View {
        let music = context.music
        Group {
            if let info = music.info {
                NowPlayingCard(
                    info: info, errorMessage: music.errorMessage,
                    onPrevious: music.previous, onPlayPause: music.playPause, onNext: music.next)
            } else {
                Text("Müzik bağlı değil.").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            }
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.music)
    }
}
